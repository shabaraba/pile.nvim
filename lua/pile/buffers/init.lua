local globals = require('pile.globals')
local window = require('pile.windows')
local picker = require('pile.windows.picker')
local log = require('pile.log')
local filter = require('pile.buffers.filter')
local disambiguate = require('pile.buffers.disambiguate')

local M = {}

local function get_buffer_windows(buf)
  local windows = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local win_buf = vim.api.nvim_win_get_buf(win)
      if win_buf == buf and win ~= globals.sidebar_win and win_buf ~= globals.sidebar_buf
        and window.is_normal_window(win) then
        table.insert(windows, win)
      end
    end
  end
  return windows
end

local function collect_buffer_info()
  local result = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if filter.is_trackable_buffer(buf) then
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
  local all_buffer_info = collect_buffer_info()

  for _, info in ipairs(all_buffer_info) do
    if filter.is_displayable_buffer(info) then
      table.insert(buffer_list, {
        buf = info.buf,
        name = info.name,
        filename = info.filename,
        filetype = info.filetype,
        window_ids = info.window_ids,
      })
    end
  end

  disambiguate.apply(buffer_list)

  local aliases = require('pile.storage.session_store').get_aliases()
  for _, buffer in ipairs(buffer_list) do
    buffer.alias = aliases[buffer.name]
  end

  log.debug("Final buffer list:")
  for i, buffer in ipairs(buffer_list) do
    log.debug(string.format("[%d] buf: %d, filename: %s", i, buffer.buf, buffer.filename))
  end

  local reorder = require('pile.features.reorder')
  if reorder.is_enabled() then
    buffer_list = reorder.sort_buffers_by_session_order(buffer_list)
  end

  return buffer_list
end

function M.get_current()
  return vim.api.nvim_get_current_buf()
end

--- @param props { buffer: table|nil, available_windows: number[] }
function M.open_selected(props)
  local selected_buffer = props.buffer
  if not selected_buffer then
    print("No buffer selected.")
    return
  end

  local window_count = #props.available_windows
  if window_count == 1 then
    window.set_buffer(props.available_windows[1], selected_buffer.buf)
  elseif window_count > 1 then
    local target_win = picker.select_window(props.available_windows)
    if target_win then
      window.set_buffer(target_win, selected_buffer.buf)
    end
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
