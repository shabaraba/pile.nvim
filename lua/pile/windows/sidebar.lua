local globals = require 'pile.globals'
local buffers = require 'pile.buffers'
local log = require 'pile.log'
local window_colors = require 'pile.window_colors'
local config = require 'pile.config'

local buffer_list = {}
local ns_id = vim.api.nvim_create_namespace('pile_window_indicators')

local M = {}

local function create_sidebar()
  globals.sidebar_buf = vim.api.nvim_create_buf(false, true)
  vim.cmd('topleft vsplit')
  globals.sidebar_win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(globals.sidebar_win, globals.sidebar_buf)
  vim.api.nvim_win_set_width(globals.sidebar_win, 35)
end

local function buffer_list_to_lines()
  local lines = {}
  for _, buffer in ipairs(buffer_list) do
    table.insert(lines, buffer.filename)
  end
  return lines
end

local function highlight_current_buffer(target_buffer)
  for i, buffer in ipairs(buffer_list) do
    if buffer.buf == target_buffer then
      vim.api.nvim_buf_add_highlight(globals.sidebar_buf, -1, "SidebarCurrentBuffer", i - 1, 0, -1)
    end
  end
end

local function is_sidebar_window(window_id, win_buf)
  return window_id == globals.sidebar_win
    or win_buf == globals.sidebar_buf
end

local function build_indicator_virt_text(window_ids)
  local virt_text = {}

  for _, window_id in ipairs(window_ids) do
    local win_buf = vim.api.nvim_win_get_buf(window_id)
    if not is_sidebar_window(window_id, win_buf) then
      local color = window_colors.assign_color(window_id, config.window_indicator.colors)
      if color then
        window_colors.apply_to_window(window_id)
        local hl_group = string.format("PileWindowIndicator_%d", window_id)
        table.insert(virt_text, {"\226\150\136", hl_group})
      end
    end
  end

  return virt_text
end

local function apply_window_indicators()
  if not config.window_indicator or not config.window_indicator.enabled then
    return
  end

  vim.api.nvim_buf_clear_namespace(globals.sidebar_buf, ns_id, 0, -1)

  window_colors.cleanup()
  if vim.tbl_isempty(window_colors.get_all_mappings()) then
    window_colors.reset()
  end

  for i, buffer in ipairs(buffer_list) do
    if buffer.window_ids and #buffer.window_ids > 0 then
      local virt_text = build_indicator_virt_text(buffer.window_ids)

      if #virt_text > 0 then
        table.insert(virt_text, {" ", "Normal"})
        vim.api.nvim_buf_set_extmark(globals.sidebar_buf, ns_id, i - 1, 0, {
          virt_text = virt_text,
          virt_text_pos = "inline",
          priority = 100,
        })
      end
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
    local buffer = buffer_list[current_line]
    if buffer then
      vim.api.nvim_buf_delete(buffer.buf, { force = true })
      M.update()
    end
  end, { buffer = globals.sidebar_buf, noremap = true, silent = true })

  vim.keymap.set('x', 'd', function()
    local start_line = vim.fn.getpos('v')[2]
    local end_line = vim.fn.getpos('.')[2]

    local from_line = math.min(start_line, end_line)
    local to_line = math.max(start_line, end_line)

    for line = from_line, to_line do
      local selected_buffer = buffer_list[line]
      if selected_buffer then
        vim.api.nvim_buf_delete(selected_buffer.buf, { force = true })
      end
    end
    M.update()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
  end, { buffer = globals.sidebar_buf, noremap = true, silent = true })
end

function M.open()
  if M.is_opened() then
    print("Sidebar already open.")
    return
  end

  M._is_opening = true

  create_sidebar()
  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', true)

  buffer_list = buffers.get_list()
  vim.api.nvim_buf_set_lines(globals.sidebar_buf, 0, -1, false, buffer_list_to_lines())
  highlight_current_buffer(buffers.get_current())
  apply_window_indicators()

  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', false)
  set_keymaps()

  M._is_opening = false
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

function M.update()
  if M._is_opening then
    return
  end

  if not globals.sidebar_buf or not vim.api.nvim_buf_is_valid(globals.sidebar_buf) then
    return
  end

  buffer_list = buffers.get_list()

  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(globals.sidebar_buf, 0, -1, false, buffer_list_to_lines())
  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', false)

  highlight_current_buffer(vim.api.nvim_get_current_buf())
  apply_window_indicators()

  if globals.sidebar_win and vim.api.nvim_win_is_valid(globals.sidebar_win) then
    vim.api.nvim_win_set_width(globals.sidebar_win, 35)
  end
end

vim.api.nvim_create_autocmd({"BufAdd", "BufLeave"}, {
  pattern = "*",
  callback = function()
    log.debug("Buffer event - updating sidebar")
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

vim.api.nvim_create_autocmd("FileType", {
  pattern = {"*"},
  callback = function(ev)
    if ev.match ~= "oil" and ev.match ~= "oilBrowser" then
      vim.defer_fn(function()
        M.update()
      end, 200)
    end
  end
})

return M
