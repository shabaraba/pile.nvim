local globals = require('pile.globals')
local window = require('pile.windows')
local popup = require('pile.windows.popup')
local log = require('pile.log')
local config = require('pile.config')

local M = {}

local selected_buffer = nil

local function get_buffer_windows(buf)
  local windows = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local win_buf = vim.api.nvim_win_get_buf(win)
      if win_buf == buf and win ~= globals.sidebar_win and win_buf ~= globals.sidebar_buf then
        table.insert(windows, win)
      end
    end
  end
  return windows
end

local function is_oil_buffer(name, filetype)
  return filetype == 'oil' or filetype:match("^oil") or name:match("^oil://")
end

local function is_displayable_buffer(info)
  return info.filename ~= ""
    and info.buftype ~= 'popup'
    and info.filetype ~= 'notify'
    and info.buftype ~= 'nofile'
    and not is_oil_buffer(info.name, info.filetype)
end

local function split_path_segments(path)
  local segments = {}
  for segment in string.gmatch(path, "[^/\\\\]+") do
    table.insert(segments, segment)
  end
  return segments
end

local function find_unique_segment(segments, other_paths)
  for i = 1, #segments - 1 do
    local segment = segments[i]
    local is_unique = true

    for _, other_segments in ipairs(other_paths) do
      for j = 1, #other_segments - 1 do
        if other_segments[j] == segment then
          is_unique = false
          break
        end
      end
      if not is_unique then
        break
      end
    end

    if is_unique then
      return segment
    end
  end
  return nil
end

local function generate_display_path(segments, filename)
  local segment_count = #segments
  if segment_count > 3 then
    return segments[segment_count - 2] .. "/" .. segments[segment_count - 1] .. "/" .. filename
  elseif segment_count > 2 then
    return segments[segment_count - 1] .. "/" .. filename
  end
  return nil
end

local function process_duplicate_files(buffers_group, filename)
  local path_segments = {}
  for _, buffer in ipairs(buffers_group) do
    path_segments[buffer.buf] = split_path_segments(buffer.name)
  end

  for i, buffer in ipairs(buffers_group) do
    local segments = path_segments[buffer.buf]
    local other_paths = {}
    for j, other_buffer in ipairs(buffers_group) do
      if i ~= j then
        table.insert(other_paths, path_segments[other_buffer.buf])
      end
    end

    local unique_segment = find_unique_segment(segments, other_paths)
    if unique_segment then
      buffer.filename = unique_segment .. "/" .. filename
    else
      local display_path = generate_display_path(segments, filename)
      buffer.filename = display_path or vim.fn.fnamemodify(buffer.name, ":~:.")
    end
  end
end

local function collect_buffer_info()
  local result = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      local window_ids = get_buffer_windows(buf)
      table.insert(result, {
        buf = buf,
        name = name,
        filename = vim.fn.fnamemodify(name, ":t"),
        buftype = vim.bo[buf].buftype,
        filetype = vim.bo[buf].filetype,
        displayed = #window_ids > 0,
        window_ids = window_ids,
      })
    end
  end
  return result
end

function M.get_list()
  local buffer_list = {}
  local filenames = {}
  local all_buffer_info = collect_buffer_info()

  for _, info in ipairs(all_buffer_info) do
    if is_displayable_buffer(info) then
      filenames[info.filename] = (filenames[info.filename] or 0) + 1
      table.insert(buffer_list, {
        buf = info.buf,
        name = info.name,
        filename = info.filename,
        window_ids = info.window_ids,
      })
    end
  end

  local duplicate_groups = {}
  for _, buffer in ipairs(buffer_list) do
    if filenames[buffer.filename] > 1 then
      duplicate_groups[buffer.filename] = duplicate_groups[buffer.filename] or {}
      table.insert(duplicate_groups[buffer.filename], buffer)
    end
  end

  for filename, group in pairs(duplicate_groups) do
    process_duplicate_files(group, filename)
  end

  log.debug("Final buffer list:")
  for i, buffer in ipairs(buffer_list) do
    log.debug(string.format("[%d] buf: %d, filename: %s", i, buffer.buf, buffer.filename))
  end

  if config.session and config.session.preserve_order then
    local reorder = require('pile.features.reorder')
    buffer_list = reorder.sort_buffers_by_session_order(buffer_list)
  end

  return buffer_list
end

function M.get_current()
  return vim.api.nvim_get_current_buf()
end

local function open_selected_callback(choice)
  if choice then
    window.set_buffer(choice, selected_buffer.buf)
  end
  popup.unmount()
end

function M.open_selected(props)
  local cursor = vim.api.nvim_win_get_cursor(globals.sidebar_win)
  local line = cursor[1]
  selected_buffer = M.get_list()[line]
  if not selected_buffer then
    print("No buffer selected.")
    return
  end

  local window_count = #props.available_windows
  if window_count == 1 then
    window.set_buffer(props.available_windows[1], selected_buffer.buf)
  elseif window_count > 1 then
    popup.select_window(props.available_windows, open_selected_callback)
  else
    window.set_buffer(nil, selected_buffer.buf)
  end
end

local function switch_buffer(offset)
  local buffer_list = M.get_list()
  local current_buf = M.get_current()
  for i, buffer in ipairs(buffer_list) do
    if buffer.buf == current_buf then
      local target_index = ((i - 1 + offset) % #buffer_list) + 1
      vim.api.nvim_set_current_buf(buffer_list[target_index].buf)
      return
    end
  end
end

function M.next()
  switch_buffer(1)
end

function M.prev()
  switch_buffer(-1)
end

return M
