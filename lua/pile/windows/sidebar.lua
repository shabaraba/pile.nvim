local globals = require 'pile.globals'
local buffers = require 'pile.buffers'

local buffer_list = {}

local M = {}

function M.open()
  if M.is_opened() then
    print("Sidebar already open.")
    return
  end

  globals.sidebar_buf = vim.api.nvim_create_buf(false, true)

  vim.cmd('topleft vsplit')
  globals.sidebar_win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(globals.sidebar_win, globals.sidebar_buf)
  vim.api.nvim_win_set_width(globals.sidebar_win, 30)

  local lines = {}

  buffer_list = buffers.get_list()
  for _, buffer in ipairs(buffer_list) do
    table.insert(lines, buffer.filename)
  end
  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(globals.sidebar_buf, 0, -1, false, lines)

  local current_buf = buffers.get_current()
  for i, buffer in ipairs(buffer_list) do
    if buffer.buf == current_buf then
      vim.api.nvim_buf_add_highlight(globals.sidebar_buf, -1, "SidebarCurrentBuffer", i - 1, 0, -1)
    end
  end

  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', false)
  -- vim.api.nvim_buf_set_keymap(globals.sidebar_buf, 'n', '<CR>', ':lua require"coluffers.windows".select_to_open()<CR>',
  --   { noremap = true, silent = true })
  vim.keymap.set('n', '<CR>', function()
    local available_windows = require('coluffers.windows').get_available_windows()
    require 'coluffers.buffers'.open_selected({ available_windows = available_windows })
  end, { buffer = globals.sidebar_buf, noremap = true, silent = true })
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
