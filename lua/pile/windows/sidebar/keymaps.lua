local globals = require 'pile.globals'
local register = require 'pile.features.register'
local transfer = require 'pile.features.transfer'
local groups = require 'pile.buffers.groups'
local preview = require 'pile.windows.preview'
local tab_actions = require 'pile.windows.sidebar.tab_actions'
local wins = require 'pile.windows.sidebar.wins'

local M = {}

local function get_current_line()
  return vim.api.nvim_win_get_cursor(wins.get())[1]
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

--- @param sidebar table Sidebar module providing get_buffer_list(), get_rows(), get_row_at_cursor(), get_buffer_at_cursor() and update()
function M.setup(sidebar)
  set_keymap('n', 'a', function()
    require('pile.windows.sidebar.edit_mode').enter(sidebar, 'alias')
  end, "Edit display names")

  set_keymap('n', 'e', function()
    require('pile.windows.sidebar.edit_mode').enter(sidebar, 'file')
  end, "Edit file paths")

  local function row_at_cursor()
    local row = sidebar.get_row_at_cursor()
    return row and row.buffer and row or nil
  end

  local function selected_rows()
    local from_line, to_line = get_visual_range()
    return vim.tbl_filter(function(row)
      return row.buffer ~= nil
    end, vim.list_slice(sidebar.get_rows(), from_line, to_line))
  end

  -- On a header, both p and P put at the top of its group
  local function paste(offset)
    if register.is_empty() then
      print("Register is empty")
      return
    end

    local row = sidebar.get_row_at_cursor()
    if not row then
      return
    end
    local entries = register.paste()
    transfer.place(row.group, entries, row.index and row.index + offset or 0, sidebar.get_buffer_list())
    sidebar.update()
    print(string.format("Pasted %d buffer(s)", #entries))
  end

  -- Only buffers within one group move; past its ends they go to the adjacent group
  local function move_rows(from_line, to_line, step)
    local rows = sidebar.get_rows()
    local group = transfer.shift_rows(rows, from_line, to_line, step, sidebar.get_buffer_list())
    if not group then
      return nil
    end
    sidebar.update()
    return groups.find_row(sidebar.get_rows(), rows[from_line].buffer.buf, group.tab)
  end

  local function move_line(step)
    local line = get_current_line()
    local new_line = move_rows(line, line, step)
    if new_line then
      vim.api.nvim_win_set_cursor(wins.get(), {new_line, 0})
    end
  end

  local function move_selection(direction)
    local from_line, to_line = get_visual_range()
    local new_line = move_rows(from_line, to_line, direction == "down" and 1 or -1)
    if new_line then
      restore_visual_selection(new_line, new_line + to_line - from_line)
    end
  end

  -- The "Unassigned" header has no tab and takes no tab action
  local function on_header(action, ...)
    local row = sidebar.get_row_at_cursor()
    if row and not row.buffer then
      if row.group.tab then
        action(row.group.tab, ...)
      end
      return true
    end
  end

  set_keymap('n', 'o', function() on_header(tab_actions.new, 0) end, "New tab after this tab")
  set_keymap('n', 'O', function() on_header(tab_actions.new, -1) end, "New tab before this tab")

  set_keymap('n', '<CR>', function()
    if on_header(tab_actions.go) then
      return
    end
    local available_windows = require('pile.windows').get_available_windows()
    require('pile.buffers').open_selected({
      buffer = sidebar.get_buffer_at_cursor(),
      available_windows = available_windows,
    })
  end, "Open buffer")

  set_keymap('n', 'dd', function()
    local row = row_at_cursor()
    if row then
      register.cut({row})
      sidebar.update()
    end
  end, "Cut buffer")

  set_keymap('x', 'd', function()
    register.cut(selected_rows())
    sidebar.update()
    exit_visual_mode()
  end, "Cut selection")

  set_keymap('n', 'yy', function()
    local row = row_at_cursor()
    if row then
      register.yank({row})
      print("Yanked 1 buffer")
    end
  end, "Yank buffer")

  set_keymap('x', 'y', function()
    print(string.format("Yanked %d buffer(s)", register.yank(selected_rows())))
    exit_visual_mode()
  end, "Yank selection")

  set_keymap('n', 'p', function() paste(0) end, "Paste below")
  set_keymap('n', 'P', function() paste(-1) end, "Paste above")

  set_keymap('n', 'D', function()
    if on_header(tab_actions.close) then
      return
    end
    local buffer = sidebar.get_buffer_at_cursor()
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
