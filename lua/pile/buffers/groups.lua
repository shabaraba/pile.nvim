--- Split the buffer list into one group per tab plus an "unassigned" group
--- A buffer that belongs to several tabs appears in each of their groups. Each
--- group keeps the order of the buffer list.
local membership = require('pile.buffers.membership')

local M = {}

local function in_tab(buffer, tab)
  local window_ids = vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_tabpage(win) == tab
  end, buffer.window_ids or {})
  return vim.tbl_extend('force', buffer, { window_ids = window_ids })
end

--- Buffers that belong to `tab`, in list order, with only that tab's windows
--- @param buffer_list table[] Entries from buffers.get_list()
--- @param tab number|nil Tabpage; defaults to the current tab
--- @return table[]
function M.of_tab(buffer_list, tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  local result = {}
  for _, buffer in ipairs(buffer_list) do
    if membership.has(tab, buffer.buf) then
      table.insert(result, in_tab(buffer, tab))
    end
  end
  return result
end

--- @param buffer_list table[] Entries from buffers.get_list()
--- @return table[] groups {tab, label, buffers}; the unassigned group has no tab and is left out when empty
function M.build(buffer_list)
  local groups, assigned = {}, {}

  for number, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local group = { tab = tab, label = 'Tab ' .. number, buffers = M.of_tab(buffer_list, tab) }
    for _, buffer in ipairs(group.buffers) do
      assigned[buffer.buf] = true
    end
    table.insert(groups, group)
  end

  local unassigned = { label = 'Unassigned', buffers = {} }
  for _, buffer in ipairs(buffer_list) do
    if not assigned[buffer.buf] then
      table.insert(unassigned.buffers, buffer)
    end
  end
  if #unassigned.buffers > 0 then
    table.insert(groups, unassigned)
  end

  return groups
end

--- One row per sidebar line: a group header, or a buffer of that group
--- @return table[] rows {group, buffer|nil, index|nil}; index is the position in group.buffers
function M.rows(groups)
  local rows = {}
  for _, group in ipairs(groups) do
    table.insert(rows, { group = group })
    for index, buffer in ipairs(group.buffers) do
      table.insert(rows, { group = group, buffer = buffer, index = index })
    end
  end
  return rows
end

--- Apply a new order of one group to the whole buffer list
--- The group's buffers are placed together, in their new order, where the
--- first of them stood; the other buffers keep their positions.
--- @param buffer_list table[] Whole list, in stored order
--- @param old_group table[] Buffers of the group before the change
--- @param new_group table[] Buffers of the group after the change (may add or drop some)
--- @return table[]
function M.merge_order(buffer_list, old_group, new_group)
  local in_group = {}
  for _, buffer in ipairs(old_group) do
    in_group[buffer.name] = true
  end
  for _, buffer in ipairs(new_group) do
    in_group[buffer.name] = true
  end

  local result, placed = {}, false
  for _, buffer in ipairs(buffer_list) do
    if not in_group[buffer.name] then
      table.insert(result, buffer)
    elseif not placed then
      vim.list_extend(result, new_group)
      placed = true
    end
  end
  if not placed then
    vim.list_extend(result, new_group)
  end
  return result
end

return M
