--- Optional 'tabline' that shows the tab names given in the sidebar
local tab_names = require 'pile.tab_names'

local M = {}

local EXPR = "%!v:lua.require'pile.tabline'.render()"

function M.render()
  local current, parts = vim.fn.tabpagenr(), {}
  for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local hl = i == current and 'TabLineSel' or 'TabLine'
    local label = tab_names.label(tab):gsub('%%', '%%%%')
    table.insert(parts, string.format('%%#%s#%%%dT %s ', hl, i, label))
  end
  return table.concat(parts) .. '%#TabLineFill#%T'
end

--- Set pile's tabline, or remove it when disabled; a tabline set by others is left alone
--- @param enabled boolean
function M.apply(enabled)
  if enabled then
    vim.o.tabline = EXPR
  elseif vim.o.tabline == EXPR then
    vim.o.tabline = ''
  end
end

return M
