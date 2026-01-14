local session_store = require('pile.storage.session_store')
local log = require('pile.log')

local M = {}

function M.get_buffer_order(buf)
  local session = session_store.get_current_session()
  if not session or not session.buffers then
    return nil
  end

  local buf_path = vim.api.nvim_buf_get_name(buf)
  for _, buf_data in ipairs(session.buffers) do
    if buf_data.path == buf_path then
      return buf_data.order
    end
  end

  return nil
end

function M.sort_buffers_by_session_order(buffer_list)
  local session = session_store.get_current_session()
  if not session or not session.buffers then
    return buffer_list
  end

  local path_to_order = {}
  for _, buf_data in ipairs(session.buffers) do
    path_to_order[buf_data.path] = buf_data.order
  end

  local sorted = vim.deepcopy(buffer_list)
  table.sort(sorted, function(a, b)
    local order_a = path_to_order[a.name] or 999999
    local order_b = path_to_order[b.name] or 999999
    
    if order_a == order_b then
      return a.buf < b.buf
    end
    
    return order_a < order_b
  end)

  return sorted
end

local function is_valid_index(index, list_size)
  return index >= 1 and index <= list_size
end

function M.move_buffer(from_index, to_index, buffer_list)
  if from_index == to_index then
    return buffer_list
  end

  local list_size = #buffer_list
  if not is_valid_index(from_index, list_size) then
    log.warn("Invalid from_index: " .. from_index)
    return buffer_list
  end
  if not is_valid_index(to_index, list_size) then
    log.warn("Invalid to_index: " .. to_index)
    return buffer_list
  end

  local reordered = vim.deepcopy(buffer_list)
  local item = table.remove(reordered, from_index)
  table.insert(reordered, to_index, item)

  for i, buf in ipairs(reordered) do
    buf.order = i - 1
  end

  return reordered
end

function M.move_range(from_line, to_line, direction, buffer_list)
  local list_size = #buffer_list

  if from_line < 1 or to_line > list_size or from_line > to_line then
    log.warn("Invalid range: " .. from_line .. " to " .. to_line)
    return buffer_list
  end

  local range_size = to_line - from_line + 1
  local target_start = direction == "down" and to_line + 1 or from_line - 1

  if direction == "down" and to_line >= list_size then
    return buffer_list
  end
  if direction == "up" and from_line <= 1 then
    return buffer_list
  end

  local reordered = vim.deepcopy(buffer_list)
  local selected_items = {}

  for i = to_line, from_line, -1 do
    table.insert(selected_items, 1, table.remove(reordered, i))
  end

  local insert_pos = direction == "down" and target_start - range_size + 1 or target_start
  for _, item in ipairs(selected_items) do
    table.insert(reordered, insert_pos, item)
    insert_pos = insert_pos + 1
  end

  for i, buf in ipairs(reordered) do
    buf.order = i - 1
  end

  return reordered
end

function M.save_buffer_order(buffer_list)
  local session_name = session_store.get_current_session_name()
  local buffers = {}

  for i, buf in ipairs(buffer_list) do
    table.insert(buffers, {
      path = buf.name,
      order = i - 1
    })
  end

  return session_store.save_session(session_name, buffers)
end

return M
