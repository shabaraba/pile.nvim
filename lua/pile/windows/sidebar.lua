local globals = require 'pile.globals'
local buffers = require 'pile.buffers'
local log = require 'pile.log'
local sqlite = require 'pile.repositories.sqlite'

local buffer_list = {}

local M = {}

-- サイドバーウィンドウを作成する関数
local function create_sidebar()
  -- サイドバー用のバッファを作成
  globals.sidebar_buf = vim.api.nvim_create_buf(false, true)
  
  -- 現在のウィンドウ数をチェック
  local windows = vim.api.nvim_list_wins()
  local normal_win_count = 0
  
  -- 通常のウィンドウ数をカウント（特殊なバッファウィンドウを除外）
  for _, win in ipairs(windows) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
      local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
      
      -- 通常のウィンドウとしてカウントする条件
      if buftype ~= 'nofile' and buftype ~= 'popup' and filetype ~= 'notify' then
        normal_win_count = normal_win_count + 1
      end
    end
  end
  
  log.debug("Normal window count: " .. normal_win_count)
  
  -- スタートアップ画面などの特殊状態の検出
  local special_buffer_active = false
  local current_buf = vim.api.nvim_get_current_buf()
  local current_ft = vim.api.nvim_buf_get_option(current_buf, 'filetype')
  
  -- スタートアップ画面系プラグインの検出
  if current_ft == 'alpha' or current_ft == 'dashboard' or current_ft == 'startify' then
    special_buffer_active = true
    log.debug("Special startup buffer detected: " .. current_ft)
  end
  
  -- サイドバー用のウィンドウを作成
  if normal_win_count <= 1 or special_buffer_active then
    -- 特殊なバッファが表示されている場合は新しいウィンドウを作成せず
    -- 現在のウィンドウを分割する
    vim.cmd('topleft vsplit')
  else
    -- 通常時は左側に新しいウィンドウを作成
    vim.cmd('topleft vsplit')
  end
  
  -- 作成されたウィンドウをサイドバーとして設定
  globals.sidebar_win = vim.api.nvim_get_current_win()
  globals.sidebar_win_id = vim.api.nvim_win_get_number(globals.sidebar_win)
  
  -- ウィンドウにサイドバーバッファを設定
  vim.api.nvim_win_set_buf(globals.sidebar_win, globals.sidebar_buf)
  vim.api.nvim_win_set_width(globals.sidebar_win, 30)
end

local function set_buffer_lines()
  local lines = {}

  buffer_list = buffers.get_list()
  
  -- バッファリストが空の場合、セッションから読み込んだバッファ情報が利用可能か確認
  if #buffer_list == 0 and sqlite._loaded_buffers and #sqlite._loaded_buffers > 0 then
    log.info("Using session loaded buffers for sidebar display")
    -- セッションから読み込んだバッファを使用
    for _, buffer_info in ipairs(sqlite._loaded_buffers) do
      if vim.api.nvim_buf_is_valid(buffer_info.buf) then
        local name = buffer_info.path
        local filename = vim.fn.fnamemodify(name, ":t")
        table.insert(buffer_list, {
          buf = buffer_info.buf,
          name = name,
          filename = filename
        })
      end
    end
  end
  
  -- デバッグ情報: サイドバーに表示する前のバッファリスト
  log.debug("Sidebar Buffer List Before Display:")
  for i, buffer in ipairs(buffer_list) do
    log.debug(string.format("[%d] buf: %d, name: %s, filename: %s", 
                           i, buffer.buf, buffer.name, buffer.filename))
  end
  
  for _, buffer in ipairs(buffer_list) do
    table.insert(lines, buffer.filename)
  end
  vim.api.nvim_buf_set_lines(globals.sidebar_buf, 0, -1, false, lines)
  
  -- デバッグ情報: 実際にサイドバーに表示された内容
  local displayed_lines = vim.api.nvim_buf_get_lines(globals.sidebar_buf, 0, -1, false)
  log.debug("Sidebar Displayed Lines:")
  for i, line in ipairs(displayed_lines) do
    log.debug(string.format("[%d] %s", i, line))
  end
end

local function highlight_buffer(target_buffer)
  buffer_list = buffers.get_list()
  for i, buffer in ipairs(buffer_list) do
    if buffer.buf == target_buffer then
      vim.api.nvim_buf_add_highlight(globals.sidebar_buf, -1, "SidebarCurrentBuffer", i - 1, 0, -1)
    end
  end
end

local function set_keymaps()
  vim.keymap.set('n', '<CR>', function()
    local available_windows = require('pile.windows').get_available_windows()
    require 'pile.buffers'.open_selected({ available_windows = available_windows })
  end, { buffer = globals.sidebar_buf, noremap = true, silent = true })

  vim.keymap.set('n', 'dd', function()
    local current_win = vim.api.nvim_get_current_win()
    local current_line = vim.api.nvim_win_get_cursor(current_win)[1]
    log.info(string.format("Current line: %d", current_line))
    local buffer = buffer_list[current_line]
    if buffer then
      vim.api.nvim_buf_delete(buffer.buf, { force = true })
      M.update()
    end
  end, { buffer = globals.sidebar_buf, noremap = true, silent = true })

  vim.keymap.set('x', 'd', function()
    local start_line = vim.fn.getpos('v')[2] -- bufnr, lnum, col, offのテーブル, vはビジュアルモードの選択開始位置
    local end_line = vim.fn.getpos('.')[2] -- bufnr, lnum, col, offのテーブル, .はビジュアルモードの選択終了位置
    
    for line = start_line, end_line do
      local selected_buffer = buffer_list[line]
      if selected_buffer then
        vim.api.nvim_buf_delete(selected_buffer.buf, { force = true })
      end
    end
    M.update()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true) -- ビジュアルモードを抜ける
  end, { buffer = globals.sidebar_buf, noremap = true, silent = true })
end

function M.open()
  if M.is_opened() then
    log.debug("Sidebar already open.")
    vim.notify("Sidebar already open.", vim.log.levels.INFO)
    return
  end

  create_sidebar()
  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', true)
  set_buffer_lines()
  highlight_buffer(buffers.get_current())
  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', false)

  set_keymaps()
  log.debug("Sidebar opened successfully")
end

function M.is_opened()
  -- サイドバーウィンドウが有効かどうかを確認
  local is_valid = globals.sidebar_win and vim.api.nvim_win_is_valid(globals.sidebar_win)
  return is_valid
end

function M.close()
  if not M.is_opened() then
    log.debug("No sidebar to close.")
    return
  end
  
  -- 閉じる前にウィンドウ数を確認
  local windows = vim.api.nvim_list_wins()
  local normal_win_count = 0
  
  -- 通常のウィンドウ数をカウント（サイドバーと特殊なバッファウィンドウを除外）
  for _, win in ipairs(windows) do
    if win ~= globals.sidebar_win and vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
      local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
      
      if buftype ~= 'nofile' and buftype ~= 'popup' and filetype ~= 'notify' then
        normal_win_count = normal_win_count + 1
      end
    end
  end
  
  log.debug("Normal window count (excluding sidebar): " .. normal_win_count)
  
  -- 最後のウィンドウでない場合のみ閉じる
  if normal_win_count > 0 then
    -- pcallで安全に閉じる（エラーが発生しても続行）
    local success, error_msg = pcall(vim.api.nvim_win_close, globals.sidebar_win, true)
    if not success then
      log.error("Failed to close sidebar window: " .. tostring(error_msg))
      -- 閉じれなかった場合でもグローバル変数はクリアしておく
      globals.sidebar_win = nil
      globals.sidebar_buf = nil
      return
    end
    
    globals.sidebar_win = nil
    globals.sidebar_buf = nil
    log.debug("Sidebar closed successfully")
  else
    -- 最後のウィンドウの場合は閉じずに通知
    log.warn("Cannot close sidebar: it's the last window")
    vim.notify("Cannot close the sidebar when it's the only window", vim.log.levels.WARN)
    
    -- 別のバッファを表示するか新しいウィンドウを作成するオプションを提供
    local normal_bufs = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and buf ~= globals.sidebar_buf then
        local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
        local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
        
        if buftype ~= 'nofile' and buftype ~= 'popup' and filetype ~= 'notify' then
          table.insert(normal_bufs, buf)
        end
      end
    end
    
    if #normal_bufs > 0 then
      -- 別のバッファがあれば表示
      vim.api.nvim_win_set_buf(globals.sidebar_win, normal_bufs[1])
      -- サイドバーウィンドウはもはやサイドバーではないのでグローバル変数をクリア
      globals.sidebar_win = nil
      globals.sidebar_buf = nil
      log.debug("Replaced sidebar with another buffer")
    end
  end
end

function M.toggle()
  if M.is_opened() then
    M.close()
  else
    M.open()
  end
end

function M.update()
  if not globals.sidebar_buf or not vim.api.nvim_buf_is_valid(globals.sidebar_buf) then
    return
  end

  buffer_list = buffers.get_list()
  
  -- バッファリストが空の場合、セッションから読み込んだバッファ情報を使用
  if #buffer_list == 0 and sqlite._loaded_buffers and #sqlite._loaded_buffers > 0 then
    log.info("Update: Using session loaded buffers for sidebar display")
    -- セッションから読み込んだバッファを使用
    for _, buffer_info in ipairs(sqlite._loaded_buffers) do
      if vim.api.nvim_buf_is_valid(buffer_info.buf) then
        local name = buffer_info.path
        local filename = vim.fn.fnamemodify(name, ":t")
        table.insert(buffer_list, {
          buf = buffer_info.buf,
          name = name,
          filename = filename
        })
      end
    end
  end
  
  -- デバッグ情報: 更新時のバッファリスト
  log.debug("Update: Buffer List Before Display:")
  for i, buffer in ipairs(buffer_list) do
    log.debug(string.format("[%d] buf: %d, name: %s, filename: %s", 
                           i, buffer.buf, buffer.name, buffer.filename))
  end
  
  local lines = {}

  for _, buffer in ipairs(buffer_list) do
    table.insert(lines, buffer.filename)
  end

  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(globals.sidebar_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', false)
  
  -- デバッグ情報: 更新後のサイドバー表示内容
  local displayed_lines = vim.api.nvim_buf_get_lines(globals.sidebar_buf, 0, -1, false)
  log.debug("Update: Sidebar Displayed Lines:")
  for i, line in ipairs(displayed_lines) do
    log.debug(string.format("[%d] %s", i, line))
  end

  -- 現在のバッファをハイライト
  for i, buffer in ipairs(buffer_list) do
    log.debug(string.format("Comparing buffer: %d with current: %d", buffer.buf, vim.api.nvim_get_current_buf()))
    if buffer.buf == vim.api.nvim_get_current_buf() then
      log.debug("Found current buffer for highlighting")
      vim.api.nvim_buf_add_highlight(globals.sidebar_buf, -1, "SidebarCurrentBuffer", i - 1, 0, -1)
    end
  end
  if globals.sidebar_win and vim.api.nvim_win_is_valid(globals.sidebar_win) then
    vim.api.nvim_win_set_width(globals.sidebar_win, 30)
  end
end

-- 自動的にバッファが追加・変更・選択されたらサイドバーを更新する
vim.api.nvim_create_autocmd("BufAdd", {
  pattern = "*",
  callback = function()
    log.debug("BufAdd event - updating sidebar")
    M.update()
  end
})

vim.api.nvim_create_autocmd("BufLeave", {
  pattern = "*",
  callback = function()
    log.debug("BufLeave event - updating sidebar")
    M.update()
  end
})

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  callback = function()
    if vim.api.nvim_get_current_buf() ~= globals.sidebar_buf then
      log.debug("BufEnter event - updating sidebar")
      M.update()
    end
  end
})

-- oil.nvimでファイルを開いた後に特別な更新を行う
vim.api.nvim_create_autocmd("FileType", {
  pattern = {"*"},
  callback = function(ev)
    if ev.match ~= "oil" and ev.match ~= "oilBrowser" then
      log.debug("New file opened - updating sidebar with delay to catch oil.nvim changes")
      vim.defer_fn(function() 
        M.update() 
      end, 200) -- 少し遅延させてoil.nvimの処理完了を待つ
    end
  end
})

return M
