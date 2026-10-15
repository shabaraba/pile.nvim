local globals = require 'pile.globals'
local register = require 'pile.features.register'
local reorder = require 'pile.features.reorder'
local preview = require 'pile.windows.preview'

local M = {}

local function get_current_line()
  return vim.api.nvim_win_get_cursor(globals.sidebar_win)[1]
end

local function get_visual_range()
  local start_line = vim.fn.getpos('v')[2]
  local end_line = vim.fn.getpos('.')[2]
  return math.min(start_line, end_line), math.max(start_line, end_line)
end

local function exit_visual_mode()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
end

local function restore_visual_selection(from_line, to_line)
  vim.cmd('normal! \27')
  vim.api.nvim_buf_set_mark(globals.sidebar_buf, '<', from_line, 0, {})
  vim.api.nvim_buf_set_mark(globals.sidebar_buf, '>', to_line, 0, {})
  vim.cmd('normal! gv')
end

local function set_keymap(mode, lhs, callback, desc)
  vim.keymap.set(mode, lhs, callback, {
    buffer = globals.sidebar_buf,
    silent = true,
    desc = desc
  })
end

--- @param sidebar table Sidebar module providing get_buffer_list(), get_buffer_at_cursor() and update()
function M.setup(sidebar)
  set_keymap('n', 'a', function()
    require('pile.windows.sidebar.edit_mode').enter(sidebar, 'alias')
  end, "Edit display names")

  set_keymap('n', 'e', function()
    require('pile.windows.sidebar.edit_mode').enter(sidebar, 'file')
  end, "Edit file paths")

  local buffer_at_cursor = sidebar.get_buffer_at_cursor

  local function selected_buffers()
    local from_line, to_line = get_visual_range()
    return vim.list_slice(sidebar.get_buffer_list(), from_line, to_line)
  end

  local function paste(offset)
    if register.is_empty() then
      print("Register is empty")
      return
    end

    local count = register.get_count()
    local new_list = register.paste(get_current_line() + offset, sidebar.get_buffer_list())
    reorder.save_buffer_order(new_list)
    sidebar.update()
    print(string.format("Pasted %d buffer(s)", count))
  end

  local function move_line(step)
    local current_line = get_current_line()
    if reorder.shift(sidebar.get_buffer_list(), current_line, step) then
      sidebar.update()
      vim.api.nvim_win_set_cursor(globals.sidebar_win, {current_line + step, 0})
    end
  end

  local function move_selection(direction)
    local from_line, to_line = get_visual_range()
    local buffer_list = sidebar.get_buffer_list()
    local step = direction == "down" and 1 or -1
    if from_line + step < 1 or to_line + step > #buffer_list then
      return
    end

    reorder.save_buffer_order(reorder.move_range(from_line, to_line, direction, buffer_list))
    sidebar.update()
    restore_visual_selection(from_line + step, to_line + step)
  end

  set_keymap('n', '<CR>', function()
    local available_windows = require('pile.windows').get_available_windows()
    require('pile.buffers').open_selected({
      buffer = sidebar.get_buffer_at_cursor(),
      available_windows = available_windows,
    })
  end, "Open buffer")

  set_keymap('n', 'dd', function()
    local buffer = buffer_at_cursor()
    if buffer then
      register.cut({buffer})
      sidebar.update()
    end
  end, "Cut buffer")

  set_keymap('x', 'd', function()
    register.cut(selected_buffers())
    sidebar.update()
    exit_visual_mode()
  end, "Cut selection")

  set_keymap('n', 'yy', function()
    local buffer = buffer_at_cursor()
    if buffer then
      register.yank({buffer})
      print("Yanked 1 buffer")
    end
  end, "Yank buffer")

  set_keymap('x', 'y', function()
    local selected = selected_buffers()
    register.yank(selected)
    print(string.format("Yanked %d buffer(s)", #selected))
    exit_visual_mode()
  end, "Yank selection")

  set_keymap('n', 'p', function() paste(0) end, "Paste below")
  set_keymap('n', 'P', function() paste(-1) end, "Paste above")

  set_keymap('n', 'D', function()
    local buffer = buffer_at_cursor()
    if buffer then
      vim.api.nvim_buf_delete(buffer.buf, { force = true })
      sidebar.update()
      print("Buffer deleted")
    end
  end, "Delete buffer immediately")

  set_keymap('n', 'K', function()
    preview.toggle(sidebar.get_buffer_at_cursor())
  end, "Toggle preview")

  set_keymap('n', '<C-j>', function() move_line(1) end, "Move buffer down")
  set_keymap('n', '<C-k>', function() move_line(-1) end, "Move buffer up")
  set_keymap('x', '<C-j>', function() move_selection("down") end, "Move selection down")
  set_keymap('x', '<C-k>', function() move_selection("up") end, "Move selection up")
end

return M
