local globals = require "pile.globals"
local M = {}

-- 利用可能なウィンドウリストを取得する関数（サイドバーを除外）
function M.get_available_windows()
  local windows = vim.api.nvim_list_wins()
  local available_windows = {}

  for _, win in ipairs(windows) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
    local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')

    if win ~= globals.sidebar_win and buftype ~= 'popup' and filetype ~= 'notify' and buftype ~= 'nofile' then
      table.insert(available_windows, win)
    end
  end

  return available_windows
end

-- バッファを選択されたウィンドウで開く関数
function M.set_buffer(win, buf)
  if (win == nil) then
    -- 隣のウィンドウが存在しない場合は新しく作成する
    vim.cmd('vsplit')
    vim.api.nvim_win_set_width(globals.sidebar_win, 30)
    local new_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(new_win, buf)
  else
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_win_set_buf(win, buf)
  end
end

return M
