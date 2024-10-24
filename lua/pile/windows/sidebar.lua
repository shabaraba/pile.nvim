local globals = require 'pile.globals'
local buffers = require 'pile.buffers'

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
  for _, buffer in ipairs(buffer_list) do
    table.insert(lines, buffer.filename)
  end
  vim.api.nvim_buf_set_lines(globals.sidebar_buf, 0, -1, false, lines)
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
    vim.notify(string.format("%d", current_line), vim.log.levels.INFO)
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
  -- vim.api.nvim_buf_set_keymap(globals.sidebar_buf, 'n', '<CR>', ':lua require"pile.windows".select_to_open()<CR>',
  --   { noremap = true, silent = true })
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
  local lines = {}

  for _, buffer in ipairs(buffer_list) do
    table.insert(lines, buffer.filename)
  end

  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(globals.sidebar_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', false)

  -- 現在のバッファをハイライト
  for i, buffer in ipairs(buffer_list) do
    -- vim.notify(string.format("%d, %d", buffer.buf, vim.api.nvim_get_current_buf()), vim.log.levels.INFO)
    if buffer.buf == vim.api.nvim_get_current_buf() then
      -- vim.notify("here", vim.log.levels.INFO)
      vim.api.nvim_buf_add_highlight(globals.sidebar_buf, -1, "SidebarCurrentBuffer", i - 1, 0, -1)
    end
  end
  if globals.sidebar_win and vim.api.nvim_win_is_valid(globals.sidebar_win) then
    vim.api.nvim_win_set_width(globals.sidebar_win, 30)
  end
end

-- 自動的にバッファが追加されたらサイドバーを更新する
vim.api.nvim_create_autocmd("BufAdd", {
  pattern = "*",
  callback = function()
    M.update()
  end
})
vim.api.nvim_create_autocmd("BufLeave", {
  pattern = "*",
  callback = function()
    M.update()
  end
})
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  callback = function()
    if vim.api.nvim_get_current_buf() ~= globals.sidebar_buf then
      -- vim.notify("bufenter", vim.log.levels.INFO)
      M.update()
    end
  end
})

return M
