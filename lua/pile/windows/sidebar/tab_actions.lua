--- Tab operations on the header line of a tab group
--- The "Unassigned" group has no tab, so these do nothing on its header.
local M = {}

local function tab_number(group)
  if group.tab and vim.api.nvim_tabpage_is_valid(group.tab) then
    return vim.api.nvim_tabpage_get_number(group.tab)
  end
end

function M.go(group)
  if tab_number(group) then
    vim.api.nvim_set_current_tabpage(group.tab)
  end
end

--- @param offset number 0 opens the new tab after the group's tab, -1 before it
function M.new(group, offset)
  local number = tab_number(group)
  if number then
    vim.cmd((number + offset) .. 'tabnew')
  end
end

--- Buffers that belonged only to the closed tab move to "Unassigned", as with
--- :tabclose
function M.close(group)
  local number = tab_number(group)
  if not number then
    return
  end
  if #vim.api.nvim_list_tabpages() == 1 then
    print("Cannot close the last tab")
    return
  end
  local ok, err = pcall(vim.cmd, number .. 'tabclose')
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
  end
end

return M
