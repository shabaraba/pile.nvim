local globals = require('pile.globals')
local window = require('pile.windows')
local popup = require('pile.windows.popup')
local M = {}

local selected_buffer = nil

function M.get_list()
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

function M.get_current()
  return vim.api.nvim_get_current_buf()
end

local function open_selected_callback(choice, idx)
  if choice then
    window.set_buffer(choice, selected_buffer.buf)
  end
  popup.unmount()
end

-- @param props {available_windows: list}
function M.open_selected(props)
  local cursor = vim.api.nvim_win_get_cursor(globals.sidebar_win)
  local line = cursor[1]
  selected_buffer = M.get_list()[line]
  if not selected_buffer then
    print("No buffer selected.")
    return
  end

  -- ウィンドウが1つしかない場合、自動的にそこに開く
  if #(props.available_windows) == 1 then
    window.set_buffer(props.available_windows[1], selected_buffer.buf)
  elseif #(props.available_windows) > 1 then
    popup.select_window(props.available_windows, open_selected_callback)
  else
    window.set_buffer(nil, selected_buffer.buf)
  end
end

function M.next()
  local buffers = M.get_list()
  local current_buf = M.get_current()
  for i, buffer in ipairs(buffers) do
    if buffer.buf == current_buf then
      local next_buf = buffers[i + 1] and buffers[i + 1].buf or buffers[1].buf
      vim.api.nvim_set_current_buf(next_buf)
      return
    end
  end
end

function M.prev()
  local buffers = M.get_list()
  local current_buf = M.get_current()
  for i, buffer in ipairs(buffers) do
    if buffer.buf == current_buf then
      local prev_buf = buffers[i - 1] and buffers[i - 1].buf or buffers[#buffers].buf
      vim.api.nvim_set_current_buf(prev_buf)
      return
    end
  end
end

return M
