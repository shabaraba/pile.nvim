--- What a session stores: the saveable buffers and the split layout of every tab
local layout = require('pile.windows.layout')
local tab_groups = require('pile.features.session.tab_groups')

local M = {}

--- Check if a buffer should be saved in the session
--- Listed-but-unloaded buffers count: restore adds buffers lazily, so a buffer
--- the user never opened this session must still survive the next save.
--- @param buf number Buffer handle
--- @return boolean True if buffer should be saved
function M.is_saveable(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and (vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buflisted)
    and vim.api.nvim_buf_get_name(buf) ~= ''
    and vim.bo[buf].buftype == ''
end

--- Collect all buffers that should be saved in the session, in the stored order
--- @return table List of buffer information {buf, path, name}
function M.buffers()
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if M.is_saveable(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      table.insert(buffers, { buf = buf, path = name, name = name })
    end
  end
  return require('pile.features.reorder').in_stored_order(buffers)
end

--- Collect the split layout, name and buffers of every tab
--- Stores each tab's winlayout() tree with each window's file and size so
--- restore can rebuild the same tabs, horizontal/vertical splits and proportions.
--- Windows without a saveable file (sidebar, terminals, help) are left out, and
--- so are tabs that hold neither such a window nor a saveable buffer.
--- @param buffers table[] From M.buffers()
--- @return table|nil Layout {version = 4, tabs = {{tree, name, buffers}...}, current_tab} or nil if no tab qualifies
function M.window_layout(buffers)
  local current_tab = vim.api.nvim_get_current_tabpage()
  local is_excluded = function(win)
    return not M.is_saveable(vim.api.nvim_win_get_buf(win))
  end

  local tabs, current_index = {}, nil
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local tab_win = vim.api.nvim_tabpage_get_win(tab)

    local function serialize(node)
      if node.type == 'leaf' then
        return {
          type = 'leaf',
          bufpath = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(node.win)),
          row = node.row,
          col = node.col,
          width = node.width,
          height = node.height,
          focused = node.win == tab_win or nil,
        }
      end
      local children = {}
      for _, child in ipairs(node.children) do
        table.insert(children, serialize(child))
      end
      return { type = node.type, children = children }
    end

    local tree = layout.capture(is_excluded, tab)
    local entry = tab_groups.capture(tab, buffers)
    if tree or #entry.buffers > 0 then
      entry.tree = tree and serialize(tree)
      table.insert(tabs, entry)
      if tab == current_tab then
        current_index = #tabs
      end
    end
  end

  if #tabs == 0 then
    return nil
  end
  return { version = 4, tabs = tabs, current_tab = current_index }
end

--- A saved tab whose fields are each of the expected type or nil
local function normalize_tab(tab)
  if type(tab) ~= 'table' then
    return {}
  end
  if tab.type then
    return { tree = tab }
  end
  return {
    tree = type(tab.tree) == 'table' and tab.tree or nil,
    name = type(tab.name) == 'string' and tab.name or nil,
    buffers = type(tab.buffers) == 'table' and tab.buffers or nil,
  }
end

--- Convert a saved layout into a list of tabs {tree, name, buffers}, accepting older formats
--- version 3 stored only each tab's tree; version 2 a single tree for the
--- current tab; sessions written before split trees were stored hold a plain
--- list of windows, rebuilt side by side.
--- @param saved table Layout as stored in the session
--- @return table[] tabs, number|nil current_tab
function M.layout_tabs(saved)
  if type(saved) ~= 'table' then
    return {}, nil
  end
  if type(saved.tabs) == 'table' then
    local tabs = {}
    for i, tab in ipairs(saved.tabs) do
      tabs[i] = normalize_tab(tab)
    end
    return tabs, tonumber(saved.current_tab)
  end
  if type(saved.tree) == 'table' then
    return { { tree = saved.tree } }, 1
  end
  if #saved == 0 then
    return {}, nil
  end

  local children = {}
  for _, win_data in ipairs(saved) do
    if type(win_data) == 'table' and win_data.bufpath then
      table.insert(children, { type = 'leaf', bufpath = win_data.bufpath })
    end
  end
  return { { tree = { type = 'row', children = children } } }, 1
end

--- Count the windows in a saved layout (for logging)
function M.count_windows(saved)
  local count = 0
  for _, tab in ipairs((M.layout_tabs(saved))) do
    if tab.tree and tab.tree.type then
      count = count + #layout.leaves(tab.tree)
    end
  end
  return count
end

return M
