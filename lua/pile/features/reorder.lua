local session_store = require('pile.storage.session_store')
local config = require('pile.config')
local log = require('pile.log')
local groups = require('pile.buffers.groups')
local membership = require('pile.buffers.membership')

local M = {}

local DEFAULT_ORDER = 999999

local function update_buffer_orders(buffer_list)
  for i, buf in ipairs(buffer_list) do
    buf.order = i - 1
  end
end

local function is_valid_index(index, list_size)
  return index >= 1 and index <= list_size
end

local function is_valid_range(from_line, to_line, list_size)
  return from_line >= 1 and to_line <= list_size and from_line <= to_line
end

local function build_path_to_order_map(buffers)
  local map = {}
  for _, buf_data in ipairs(buffers) do
    map[buf_data.path] = buf_data.order
  end
  return map
end

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

  local path_to_order = build_path_to_order_map(session.buffers)
  local sorted = vim.deepcopy(buffer_list)

  table.sort(sorted, function(a, b)
    local order_a = path_to_order[a.name] or DEFAULT_ORDER
    local order_b = path_to_order[b.name] or DEFAULT_ORDER

    if order_a == order_b then
      return a.buf < b.buf
    end
    return order_a < order_b
  end)

  return sorted
end

--- The list in the stored order when session.preserve_order is on, else as given
function M.in_stored_order(buffer_list)
  if M.is_enabled() then
    return M.sort_buffers_by_session_order(buffer_list)
  end
  return buffer_list
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
  update_buffer_orders(reordered)

  return reordered
end

function M.move_range(from_line, to_line, direction, buffer_list)
  local list_size = #buffer_list

  if not is_valid_range(from_line, to_line, list_size) then
    log.warn("Invalid range: " .. from_line .. " to " .. to_line)
    return buffer_list
  end

  local is_at_boundary = (direction == "down" and to_line >= list_size)
    or (direction == "up" and from_line <= 1)
  if is_at_boundary then
    return buffer_list
  end

  local reordered = vim.deepcopy(buffer_list)
  local selected_items = {}

  for i = to_line, from_line, -1 do
    table.insert(selected_items, 1, table.remove(reordered, i))
  end

  local range_size = to_line - from_line + 1
  local insert_pos
  if direction == "down" then
    insert_pos = to_line + 1 - range_size + 1
  else
    insert_pos = from_line - 1
  end

  for _, item in ipairs(selected_items) do
    table.insert(reordered, insert_pos, item)
    insert_pos = insert_pos + 1
  end

  update_buffer_orders(reordered)
  return reordered
end

--- Move one buffer of a group up or down by `step` and persist the new order
--- @param buffer_list table[] Whole list, in stored order
--- @param tab number|nil Tab of the group; nil for the unassigned group
--- @param group_buffers table[] Buffers of the group the move happens in
--- @return boolean moved false when the move would leave the group
function M.shift(buffer_list, tab, group_buffers, index, step)
  local target = index + step
  if not is_valid_index(index, #group_buffers) or not is_valid_index(target, #group_buffers) then
    return false
  end
  M.save_group_order(buffer_list, tab, group_buffers, M.move_buffer(index, target, group_buffers))
  return true
end

local function bufs_of(group_buffers)
  return vim.tbl_map(function(buffer) return buffer.buf end, group_buffers)
end

--- Persist a new order of one group's buffers
--- A tab's group keeps it as the tab's own order. The stored list takes it as
--- well (see groups.merge_order()), so every other tab first fixes its current
--- order to stay as it is.
--- @param tab number|nil Tab of the group; nil for the unassigned group
function M.save_group_order(buffer_list, tab, old_group, new_group)
  if M.is_enabled() then
    for _, other in ipairs(vim.api.nvim_list_tabpages()) do
      if other ~= tab then
        membership.set_order(other, bufs_of(groups.of_tab(buffer_list, other)))
      end
    end
    if tab then
      membership.set_order(tab, bufs_of(new_group))
    end
  end
  return M.save_buffer_order(groups.merge_order(buffer_list, old_group, new_group))
end

--- Whether the sidebar follows the saved manual order (session.preserve_order)
function M.is_enabled()
  return config.session and config.session.preserve_order or false
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

  return session_store.save_buffers(session_name, buffers)
end

return M
