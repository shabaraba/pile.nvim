--- Rebuild the saved tabs and split trees
local capture = require('pile.features.session.capture')
local log = require('pile.log')
local layout = require('pile.windows.layout')

--- Drop windows whose file could not be restored and attach buffer handles
--- @return table|nil Normalized tree, or nil if no window is left
local function resolve_tree(node, buffer_map)
  if node.type == 'leaf' then
    local buf = node.bufpath and buffer_map[node.bufpath]
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
      return nil
    end
    return vim.tbl_extend('force', node, { buf = buf })
  end

  if (node.type ~= 'row' and node.type ~= 'col') or type(node.children) ~= 'table' then
    return nil
  end

  local children = {}
  for _, child in ipairs(node.children) do
    local resolved = type(child) == 'table' and resolve_tree(child, buffer_map)
    if resolved then
      table.insert(children, resolved)
    end
  end
  return layout.normalize({ type = node.type, children = children })
end

--- Recreate the splits of a tree inside `win`
--- Siblings are split off first, then each one is subdivided, which yields the
--- same frame structure Neovim reports from winlayout().
--- @return number|nil Window that was focused when the session was saved
local function build_splits(node, win)
  if node.type == 'leaf' then
    vim.api.nvim_win_set_buf(win, node.buf)
    return node.focused and win or nil
  end

  local split_cmd = node.type == 'row' and 'rightbelow vsplit' or 'rightbelow split'
  local wins = { win }
  for i = 2, #node.children do
    vim.api.nvim_set_current_win(wins[i - 1])
    local ok = pcall(vim.cmd, split_cmd)
    if not ok then
      -- Not enough room (E36): keep what fits rather than failing the restore
      break
    end
    wins[i] = vim.api.nvim_get_current_win()
  end

  local focused
  for i, w in ipairs(wins) do
    focused = build_splits(node.children[i], w) or focused
  end
  return focused
end

--- Rebuild one tab's splits in the current tab and size them
--- @return number|nil Window that was focused in this tab when saved
local function restore_tab(tree)
  local focused = build_splits(tree, vim.api.nvim_get_current_win())
  -- Legacy layouts carry no sizes; leave Neovim's equal split in place
  if layout.leaves(tree)[1].width then
    layout.apply(tree)
  end
  return focused or vim.api.nvim_get_current_win()
end

--- The tab's saved splits, or a window on its first buffer when it had no window to save
local function tree_of(saved_tab, buffer_map)
  if saved_tab.tree then
    return resolve_tree(saved_tab.tree, buffer_map)
  end
  for _, path in ipairs(saved_tab.buffers or {}) do
    local tree = resolve_tree({ type = 'leaf', bufpath = path }, buffer_map)
    if tree then
      return tree
    end
  end
end

--- Restore window layout
--- Rebuilds the saved tabs and split trees and scales the saved sizes to the
--- current screen.
--- @param saved table|nil Layout information from capture.window_layout()
--- @param buffer_map table|nil Mapping from file path to buffer handle
--- @return table[] restored {tab, tree, entry}: each rebuilt tab and the saved tab it came from
return function(saved, buffer_map)
  if not buffer_map or type(buffer_map) ~= 'table' then
    log.debug("Invalid buffer_map provided to restore_window_layout")
    return {}
  end

  local saved_tabs, saved_current = capture.layout_tabs(saved)
  local restored, current_index = {}, nil
  for i, saved_tab in ipairs(saved_tabs) do
    local tree = tree_of(saved_tab, buffer_map)
    if tree then
      table.insert(restored, { tree = tree, entry = saved_tab })
      if i == saved_current then
        current_index = #restored
      end
    end
  end
  if #restored == 0 then
    log.debug("No layout to restore or invalid layout type")
    return {}
  end

  -- The sidebar must not be the window that survives :only
  local sidebar = require('pile.windows.sidebar')
  local sidebar_was_open = sidebar.is_opened()
  if sidebar_was_open then
    sidebar.close()
  end

  -- Close all tabs and windows except current to avoid "Already only one window" warning
  if #vim.api.nvim_list_tabpages() > 1 then
    vim.cmd('tabonly')
  end
  if #vim.api.nvim_list_wins() > 1 then
    vim.cmd('only')
  end

  local focused = {}
  for i, item in ipairs(restored) do
    if i > 1 then
      -- :tab split reuses the current buffer instead of creating an empty one
      vim.cmd('tab split')
    end
    focused[i] = restore_tab(item.tree)
    item.tab = vim.api.nvim_get_current_tabpage()
  end

  local target = focused[current_index or 1]
  if target and vim.api.nvim_win_is_valid(target) then
    vim.api.nvim_set_current_win(target)
  end

  if sidebar_was_open then
    sidebar.open()
    if target and vim.api.nvim_win_is_valid(target) then
      vim.api.nvim_set_current_win(target)
    end
  end
  return restored
end
