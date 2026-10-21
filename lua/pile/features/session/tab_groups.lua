--- Each tab's name and buffers, in its group's order, as stored in sessions
local groups = require('pile.buffers.groups')
local membership = require('pile.buffers.membership')
local tab_names = require('pile.tab_names')

local M = {}

--- @param buffers table[] Saveable buffers {buf, name}, in stored order
--- @return table {name, buffers = paths}
function M.capture(tab, buffers)
  local paths = vim.tbl_map(function(buffer)
    return buffer.name
  end, groups.of_tab(buffers, tab))
  return { name = tab_names.get(tab), buffers = paths }
end

--- Give the restored tabs their saved names and buffers
--- Buffers saved in no tab are left unassigned, while buffers that were open
--- before the restore and are in no saved tab join the current tab. Sessions
--- saved before tab groups were stored carry no buffer list; such a tab keeps
--- what restoring put in it.
--- @param restored table[] {tab, entry} where entry is a saved tab
--- @param buffer_map table<string, number> path -> buffer
--- @param open_before number[] Buffers listed before the restore
function M.apply(restored, buffer_map, open_before)
  local has_groups = false
  for _, item in ipairs(restored) do
    tab_names.set(item.tab, item.entry.name)
    if item.entry.buffers then
      has_groups = true
      local bufs = {}
      for _, path in ipairs(item.entry.buffers) do
        if buffer_map[path] then
          table.insert(bufs, buffer_map[path])
        end
      end
      membership.reset(item.tab, bufs)
    end
  end

  if has_groups then
    local current = vim.api.nvim_get_current_tabpage()
    for _, buf in ipairs(open_before) do
      if vim.api.nvim_buf_is_valid(buf) and #membership.tabs_of(buf) == 0 then
        membership.add(current, buf)
      end
    end
  end
end

return M
