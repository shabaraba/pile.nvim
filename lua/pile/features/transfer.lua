--- Move and share buffers between tab groups
local groups = require('pile.buffers.groups')
local membership = require('pile.buffers.membership')
local reorder = require('pile.features.reorder')
local window = require('pile.windows')

local M = {}

--- The window's alternate buffer if the tab's group has it, else the group's first buffer
local function replacement(tab, buf)
  local alternate = vim.fn.bufnr('#')
  local first
  for _, buffer in ipairs(groups.of_tab(require('pile.buffers').get_list(), tab)) do
    if buffer.buf == alternate and alternate ~= buf then
      return alternate
    end
    if buffer.buf ~= buf then
      first = first or buffer.buf
    end
  end
  return first or vim.api.nvim_create_buf(true, false)
end

--- Take `buf` out of `tab`; that tab's windows showing it switch to another of its buffers
function M.detach(tab, buf)
  membership.remove(tab, buf)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.api.nvim_win_get_buf(win) == buf and window.is_normal_window(win) then
      -- Run in the window so that the buffer shown instead joins its tab, not the current one
      -- `:buffer!` hides the buffer even with unsaved changes and 'nohidden'
      vim.api.nvim_win_call(win, function()
        vim.cmd.buffer({ replacement(tab, buf), bang = true })
      end)
    end
  end
end

--- Put buffers into a group after its `position`-th buffer (0 = top)
--- In a tab's group they join that tab; in the unassigned group they leave
--- every tab. A buffer the group already has moves to the new position.
--- @param group table Group from groups.build()
--- @param entries table[] Buffer entries to put
--- @param buffer_list table[] Whole list, in stored order
function M.place(group, entries, position, buffer_list)
  local putting = {}
  for _, entry in ipairs(entries) do
    putting[entry.buf] = true
    if group.tab then
      membership.add(group.tab, entry.buf)
    else
      for _, tab in ipairs(membership.tabs_of(entry.buf)) do
        M.detach(tab, entry.buf)
      end
    end
  end

  local new_group = position == 0 and vim.list_slice(entries) or {}
  for index, buffer in ipairs(group.buffers) do
    if not putting[buffer.buf] then
      table.insert(new_group, buffer)
    end
    if index == position then
      vim.list_extend(new_group, entries)
    end
  end
  reorder.save_group_order(buffer_list, group.tab, group.buffers, new_group)
end

local function adjacent_group(rows, group, step)
  local previous
  for _, row in ipairs(rows) do
    if not row.buffer then
      if step < 0 and row.group == group then
        return previous
      end
      if step > 0 and previous == group then
        return row.group
      end
      previous = row.group
    end
  end
end

--- Move the buffer rows `from_line`..`to_line` of one group by `step` (1 or -1)
--- Rows pushed past the group's first or last buffer go to the adjacent group.
--- @param rows table[] Sidebar rows; see groups.rows()
--- @param buffer_list table[] Whole list, in stored order
--- @return table|nil group The group the rows are in afterwards; nil when nothing moved
function M.shift_rows(rows, from_line, to_line, step, buffer_list)
  local first, last = rows[from_line], rows[to_line]
  if not (first and last and first.buffer and last.buffer and first.group == last.group) then
    return nil
  end
  local group = first.group

  if first.index + step >= 1 and last.index + step <= #group.buffers then
    local direction = step > 0 and "down" or "up"
    local moved = reorder.move_range(first.index, last.index, direction, group.buffers)
    reorder.save_group_order(buffer_list, group.tab, group.buffers, moved)
    return group
  end

  local target = adjacent_group(rows, group, step)
  if not target then
    return nil
  end
  local entries = vim.list_slice(group.buffers, first.index, last.index)
  if group.tab then
    for _, entry in ipairs(entries) do
      M.detach(group.tab, entry.buf)
    end
  end
  M.place(target, entries, step > 0 and 0 or #target.buffers, buffer_list)
  return target
end

return M
