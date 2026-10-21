--- Each tab's name and buffers, in its group's order, as stored in sessions
local groups = require('pile.buffers.groups')
local membership = require('pile.buffers.membership')
local tab_names = require('pile.tab_names')

local M = {}

--- @param buffer_list table[] From buffers.get_list()
--- @param is_saveable fun(buf: number): boolean
--- @return table {name, buffers = paths}
function M.capture(tab, buffer_list, is_saveable)
  local paths = {}
  for _, buffer in ipairs(groups.of_tab(buffer_list, tab)) do
    if is_saveable(buffer.buf) then
      table.insert(paths, buffer.name)
    end
  end
  return { name = tab_names.get(tab), buffers = paths }
end

--- Give the restored tabs their saved names and buffers
--- Buffers saved in no tab are left unassigned. Sessions saved before tab
--- groups were stored carry no buffer list; such a tab keeps what restoring
--- put in it.
--- @param restored table[] {tab, entry} where entry is a saved tab
--- @param buffer_map table<string, number> path -> buffer
function M.apply(restored, buffer_map)
  for _, item in ipairs(restored) do
    tab_names.set(item.tab, item.entry.name)
    if type(item.entry.buffers) == 'table' then
      local bufs = {}
      for _, path in ipairs(item.entry.buffers) do
        if buffer_map[path] then
          table.insert(bufs, buffer_map[path])
        end
      end
      membership.reset(item.tab, bufs)
    end
  end
end

return M
