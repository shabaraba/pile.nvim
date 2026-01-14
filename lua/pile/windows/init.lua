local globals = require "pile.globals"

local M = {}

function M.get_available_windows()
  local available_windows = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buftype = vim.bo[buf].buftype
    local filetype = vim.bo[buf].filetype
    local is_available = win ~= globals.sidebar_win
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
    vim.api.nvim_win_set_width(globals.sidebar_win, 30)
    win = vim.api.nvim_get_current_win()
  else
    vim.api.nvim_set_current_win(win)
  end
  vim.api.nvim_win_set_buf(win, buf)
end

return M
