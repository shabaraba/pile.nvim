--- What a session stores: the saveable buffers and the split layout of every tab
local layout = require('pile.windows.layout')

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

--- Collect all buffers that should be saved in the session
--- @return table List of buffer information {path, name}
function M.buffers()
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if M.is_saveable(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      table.insert(buffers, { path = name, name = name })
    end
  end
  return buffers
end

--- Collect the split layout of every tab
--- Stores each tab's winlayout() tree with each window's file and size so
--- restore can rebuild the same tabs, horizontal/vertical splits and proportions.
--- Windows without a saveable file (sidebar, terminals, help) are left out, and
--- so are tabs that hold no such window.
--- @return table|nil Layout {version = 3, tabs = {node...}, current_tab} or nil if no window qualifies
function M.window_layout()
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
    if tree then
      table.insert(tabs, serialize(tree))
      if tab == current_tab then
        current_index = #tabs
      end
    end
  end

  if #tabs == 0 then
    return nil
  end
  return { version = 3, tabs = tabs, current_tab = current_index }
end

--- Convert a saved layout into a list of tab trees, accepting older formats
--- version 2 stored a single tree for the current tab; sessions written before
--- split trees were stored hold a plain list of windows, rebuilt side by side.
--- @param saved table Layout as stored in the session
--- @return table[] trees, number|nil current_tab
function M.layout_tabs(saved)
  if type(saved) ~= 'table' then
    return {}, nil
  end
  if type(saved.tabs) == 'table' then
    return saved.tabs, tonumber(saved.current_tab)
  end
  if type(saved.tree) == 'table' then
    return { saved.tree }, 1
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
  return { { type = 'row', children = children } }, 1
end

--- Count the windows in a saved layout (for logging)
function M.count_windows(saved)
  local count = 0
  for _, tree in ipairs((M.layout_tabs(saved))) do
    if type(tree) == 'table' and tree.type then
      count = count + #layout.leaves(tree)
    end
  end
  return count
end

return M
