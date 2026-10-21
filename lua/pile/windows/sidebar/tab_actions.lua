--- Tab operations on the header line of a tab group
local M = {}

local function run(tab, command)
  if not vim.api.nvim_tabpage_is_valid(tab) then
    return
  end
  local ok, err = pcall(vim.cmd, command(vim.api.nvim_tabpage_get_number(tab)))
  if not ok then
    vim.notify(err:match('E%d+:.*') or err, vim.log.levels.ERROR)
  end
end

function M.go(tab)
  run(tab, function(number) return number .. 'tabnext' end)
end

--- @param offset number 0 opens the new tab after `tab`, -1 before it
function M.new(tab, offset)
  run(tab, function(number) return (number + offset) .. 'tabnew' end)
end

--- Like :tabclose, which keeps the buffers and refuses to close the last tab
function M.close(tab)
  run(tab, function(number) return number .. 'tabclose' end)
end

return M
