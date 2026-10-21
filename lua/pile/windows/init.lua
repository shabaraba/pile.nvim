local wins = require "pile.windows.sidebar.wins"

local M = {}

--- @param win number Window handle
--- @return boolean True if the window is a split, not a floating window
function M.is_normal_window(win)
  local relative = vim.api.nvim_win_get_config(win).relative
  return not relative or relative == ''
end

--- Windows of the current tab that can show a buffer opened from the sidebar
function M.get_available_windows()
  local available_windows = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buftype = vim.bo[buf].buftype
    local filetype = vim.bo[buf].filetype
    local is_available = not wins.is_sidebar(win)
      and M.is_normal_window(win)
      and buftype ~= 'popup'
      and buftype ~= 'nofile'
      and filetype ~= 'notify'

    if is_available then
      table.insert(available_windows, win)
    end
  end
  return available_windows
end

function M.set_buffer(win, buf)
  if win == nil then
    vim.cmd('vsplit')
    vim.api.nvim_win_set_width(wins.get(), 30)
    win = vim.api.nvim_get_current_win()
  else
    vim.api.nvim_set_current_win(win)
  end
  vim.api.nvim_win_set_buf(win, buf)
end

return M
