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

--- Move `tab` one place later (1) or earlier (-1) with :tabmove
--- @return boolean moved false at either end
function M.move(tab, step)
  if not vim.api.nvim_tabpage_is_valid(tab) then
    return false
  end
  local number = vim.api.nvim_tabpage_get_number(tab)
  if number + step < 1 or number + step > #vim.api.nvim_list_tabpages() then
    return false
  end
  -- :tabmove moves only the current tab; visiting it without autocmds leaves focus and sidebars alone
  local current = vim.api.nvim_get_current_tabpage()
  vim.cmd('noautocmd ' .. number .. 'tabnext')
  vim.cmd('tabmove ' .. (step > 0 and '+1' or '-1'))
  vim.cmd('noautocmd ' .. vim.api.nvim_tabpage_get_number(current) .. 'tabnext')
  return true
end

return M
