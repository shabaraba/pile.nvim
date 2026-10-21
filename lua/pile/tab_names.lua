--- Tab names, kept in the tab-local variable `pile_name` so that tablines can show them
local M = {}

local VAR = 'pile_name'

--- @return string|nil
function M.get(tab)
  local ok, name = pcall(vim.api.nvim_tabpage_get_var, tab, VAR)
  return ok and type(name) == 'string' and name ~= '' and name or nil
end

--- @param name string|nil nil or '' removes the name
function M.set(tab, name)
  if name and name ~= '' then
    vim.api.nvim_tabpage_set_var(tab, VAR, name)
  else
    pcall(vim.api.nvim_tabpage_del_var, tab, VAR)
  end
end

--- Name of the tab, or "Tab N" when it has none
function M.label(tab)
  return M.get(tab) or M.default_label(tab)
end

function M.default_label(tab)
  return 'Tab ' .. vim.api.nvim_tabpage_get_number(tab)
end

return M
