local globals = require 'pile.globals'
local buffers = require 'pile.buffers'
local log = require 'pile.log'
local sqlite = require 'pile.repositories.sqlite'

local buffer_list = {}

local M = {}

local function create_sidebar()
  globals.sidebar_buf = vim.api.nvim_create_buf(false, true)
  vim.cmd('topleft vsplit')
  globals.sidebar_win = vim.api.nvim_get_current_win()

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
    print("Sidebar already open.")
    return
  end

  create_sidebar()
  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', true)
  set_buffer_lines()
  highlight_buffer(buffers.get_current())
  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', false)

  set_keymaps()
end

function M.is_opened()
  return globals.sidebar_win and vim.api.nvim_win_is_valid(globals.sidebar_win)
end

function M.close()
  if M.is_opened() then
    vim.api.nvim_win_close(globals.sidebar_win, true)
    globals.sidebar_win = nil
    globals.sidebar_buf = nil
  else
    print("No sidebar to close.")
  end
end

function M.toggle()
  if M.is_opened() then
    M.close()
  else
    M.open()
  end
end

-- サイドバーを更新する関数
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
