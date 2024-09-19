-- ~/.config/nvim/lua/plugins.myplugin/init.lua
require("dressing").setup()
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local M = {}
local sidebar_buf = nil
local sidebar_win = nil
local buffer_list = {}
local popup_list = {}
local highlight_win = nil -- 選択中のウィンドウを強調するために保持

-- ハイライトグループを定義
vim.cmd("highlight SidebarCurrentBuffer guibg=#3E4452 guifg=Red")
vim.cmd("highlight SelectedWindow guibg=Red guifg=White")

-- バッファリストを取得する関数
local function get_buffer_list()
  local buffers = vim.api.nvim_list_bufs()
  local buffer_list = {}
  local filenames = {}

  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
      local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
      local name = vim.api.nvim_buf_get_name(buf)
      local filename = vim.fn.fnamemodify(name, ":t")
      -- vim.notify(buftype .. "," .. filetype, vim.log.levels.INFO)
      if filename ~= "" and buftype ~= 'popup' and filetype ~= 'notify' and buftype ~= 'nofile' then
        filenames[filename] = (filenames[filename] or 0) + 1
        table.insert(buffer_list, { buf = buf, name = name, filename = filename })
      end
    end
  end

  for _, buffer in ipairs(buffer_list) do
    if filenames[buffer.filename] > 1 then
      buffer.filename = vim.fn.fnamemodify(buffer.name, ":p:.")
    end
  end

  return buffer_list
end

-- サイドバーを開く関数
function M.open_sidebar()
  if sidebar_win and vim.api.nvim_win_is_valid(sidebar_win) then
    print("Sidebar already open.")
    return
  end

  sidebar_buf = vim.api.nvim_create_buf(false, true)

  vim.cmd('topleft vsplit')
  sidebar_win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(sidebar_win, sidebar_buf)
  vim.api.nvim_win_set_width(sidebar_win, 30)

  buffer_list = get_buffer_list()
  local lines = {}
  local current_buf = vim.api.nvim_get_current_buf()

  for _, buffer in ipairs(buffer_list) do
    table.insert(lines, buffer.filename)
  end
  vim.api.nvim_buf_set_option(sidebar_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(sidebar_buf, 0, -1, false, lines)

  for i, buffer in ipairs(buffer_list) do
    if buffer.buf == current_buf then
      vim.api.nvim_buf_add_highlight(sidebar_buf, -1, "SidebarCurrentBuffer", i - 1, 0, -1)
    end
  end

  vim.api.nvim_buf_set_option(sidebar_buf, 'modifiable', false)
  vim.api.nvim_buf_set_keymap(sidebar_buf, 'n', '<CR>', ':lua require"coluffers".select_window_to_open()<CR>',
    { noremap = true, silent = true })
end

-- サイドバーを閉じる関数
function M.close_sidebar()
  if sidebar_win and vim.api.nvim_win_is_valid(sidebar_win) then
    vim.api.nvim_win_close(sidebar_win, true)
    sidebar_win = nil
    sidebar_buf = nil
  else
    print("No sidebar to close.")
  end
end

-- 利用可能なウィンドウリストを取得する関数（サイドバーを除外）
local function get_available_windows()
  local windows = vim.api.nvim_list_wins()
  local available_windows = {}

  for _, win in ipairs(windows) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
    local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')

    if win ~= sidebar_win and buftype ~= 'popup' and filetype ~= 'notify' and buftype ~= 'nofile' then
      table.insert(available_windows, win)
    end
  end

  return available_windows
end

-- ウィンドウ強調表示を解除
local function clear_highlight()
  if highlight_win and vim.api.nvim_win_is_valid(highlight_win) then
    vim.api.nvim_win_set_option(highlight_win, 'winhighlight', '')
  end
end

-- 選択中のウィンドウを強調表示
local function highlight_selected_window(win)
  clear_highlight()
  vim.api.nvim_win_set_option(win, 'winhighlight', 'Normal:SelectedWindow')
  highlight_win = win
end

-- バッファを選択されたウィンドウで開く関数
function M.open_buffer_in_window(win, buf)
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_buf(win, buf)
  clear_highlight()
end

-- 各ウィンドウに番号を表示する関数
local function label_windows(windows)
  for _, win in ipairs(windows) do
    local buf = vim.api.nvim_create_buf(false, true)
    local label = string.format("[%d]", vim.api.nvim_win_get_number(win))
    local popup = M.show_popup_on_win(win)
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, { label })
    table.insert(popup_list, popup)
  end
end

-- ユーザーにウィンドウを選択させる関数
function M.select_window_to_open()
  local cursor = vim.api.nvim_win_get_cursor(sidebar_win)
  local line = cursor[1]
  local selected_buffer = buffer_list[line]
  if not selected_buffer then
    print("No buffer selected.")
    return
  end

  local available_windows = get_available_windows()

  -- ウィンドウが1つしかない場合、自動的にそこに開く
  if #available_windows == 1 then
    M.open_buffer_in_window(available_windows[1], selected_buffer.buf)
  elseif #available_windows > 1 then
    label_windows(available_windows)
    -- 複数のウィンドウがある場合、ユーザーに選択させる
    vim.ui.select(available_windows, {
      prompt = "Select window to open buffer:",
      format_item = function(win)
        -- リッチな表示に、ウィンドウ番号や現在のバッファ名を追加
        local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
        local bufname_short = vim.fn.fnamemodify(bufname, ":t")
        return string.format("Window %d [%s]", vim.api.nvim_win_get_number(win), bufname_short)
      end
    }, function(choice, idx)
      if choice then
        highlight_selected_window(choice)
        -- 数秒待ってから確定させる。ここで確認キーなどを追加しても良い
        vim.defer_fn(function()
          M.open_buffer_in_window(choice, selected_buffer.buf)
        end, 200)
        for _, popup in ipairs(popup_list) do
          popup:unmount()
        end
        popup_list = {}
      end
    end
    )
  else
    -- 隣のウィンドウが存在しない場合は新しく作成する
    vim.cmd('vsplit')
    vim.api.nvim_win_set_width(sidebar_win, 30)
    local new_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(new_win, selected_buffer.buf)
  end
end

-- 現在のバッファを一つ下のバッファに切り替える関数
function M.switch_to_next_buffer()
  local buffers = get_buffer_list()
  local current_buf = vim.api.nvim_get_current_buf()
  for i, buffer in ipairs(buffers) do
    if buffer.buf == current_buf then
      local next_buf = buffers[i + 1] and buffers[i + 1].buf or buffers[1].buf
      vim.api.nvim_set_current_buf(next_buf)
      return
    end
  end
end

-- 現在のバッファを一つ上のバッファに切り替える関数
function M.switch_to_prev_buffer()
  local buffers = get_buffer_list()
  local current_buf = vim.api.nvim_get_current_buf()
  for i, buffer in ipairs(buffers) do
    if buffer.buf == current_buf then
      local prev_buf = buffers[i - 1] and buffers[i - 1].buf or buffers[#buffers].buf
      vim.api.nvim_set_current_buf(prev_buf)
      return
    end
  end
end

function M.show_popup_on_win(win)
  local width = vim.api.nvim_win_get_width(win)
  local height = vim.api.nvim_win_get_height(win)

  local pos = vim.api.nvim_win_get_position(win)
  local row = pos[1]
  local col = pos[2]

  -- ポップアップのサイズを計算（ウィンドウの50%とする）
  local popup_width = 10
  local popup_height = 10

  -- ポップアップの位置を計算（中央に配置）
  -- local row = math.floor((height - popup_height) / 2)
  -- local col = math.floor((width - popup_width) / 2)

  local popup = Popup({
    enter = false,
    focusable = false,
    border = {
      style = "rounded",
    },
    position = {
      row = row,
      col = col,
    },
    size = {
      width = 10, -- 文字単位
      height = 1, -- 行単位
    },
    win_options = {
      winblend = 10,
      winhighlight = "Normal:Normal",
    },
  })
  popup:mount()
  popup:on(event.BufNew, function()
    -- 現在のバッファがポップアップのバッファでない場合、ポップアップを閉じる
    if vim.api.nvim_get_current_buf() ~= popup.bufnr then
      popup:unmount()
    end
  end)
  return popup
end

-- サイドバーを更新する関数
function M.update_sidebar()
  if not sidebar_buf or not vim.api.nvim_buf_is_valid(sidebar_buf) then
    return
  end

  buffer_list = get_buffer_list()
  local lines = {}

  for _, buffer in ipairs(buffer_list) do
    table.insert(lines, buffer.filename)
  end

  vim.api.nvim_buf_set_option(sidebar_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(sidebar_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(sidebar_buf, 'modifiable', false)

  -- 現在のバッファをハイライト
  for i, buffer in ipairs(buffer_list) do
    -- vim.notify(string.format("%d, %d", buffer.buf, vim.api.nvim_get_current_buf()), vim.log.levels.INFO)
    if buffer.buf == vim.api.nvim_get_current_buf() then
      -- vim.notify("here", vim.log.levels.INFO)
      vim.api.nvim_buf_add_highlight(sidebar_buf, -1, "SidebarCurrentBuffer", i - 1, 0, -1)
    end
  end
  if sidebar_win and vim.api.nvim_win_is_valid(sidebar_win) then
    vim.api.nvim_win_set_width(sidebar_win, 30)
  end
end

-- 自動的にバッファが追加されたらサイドバーを更新する
vim.api.nvim_create_autocmd("BufAdd", {
  pattern = "*",
  callback = function()
    M.update_sidebar()
  end
})
vim.api.nvim_create_autocmd("BufLeave", {
  pattern = "*",
  callback = function()
    M.update_sidebar()
  end
})
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  callback = function()
    if vim.api.nvim_get_current_buf() ~= sidebar_buf then
      -- vim.notify("bufenter", vim.log.levels.INFO)
      M.update_sidebar()
    end
  end
})

return M
