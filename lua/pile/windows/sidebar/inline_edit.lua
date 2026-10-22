--- Names edited directly in the sidebar: a buffer line sets its alias, a header line names its tab
local globals = require 'pile.globals'
local edit_apply = require 'pile.windows.sidebar.edit_apply'
local render = require 'pile.windows.sidebar.render'

local M = {}

local inserting = false

--- Redraws are held back while typing so that they do not overwrite the line being edited
function M.is_inserting()
  return inserting
end

--- @return boolean changed true when the lines differed from the rows
local function apply_edits(sidebar)
  local rows = sidebar.get_rows()
  local texts = render.lines(rows)
  local lines = vim.api.nvim_buf_get_lines(globals.sidebar_buf, 0, -1, false)
  if vim.deep_equal(lines, texts) then
    return false
  end

  local entries = {}
  for i, row in ipairs(rows) do
    entries[i] = { row = row, text = texts[i] }
  end
  local changes, tab_changes, invalid = edit_apply.collect(entries, lines, true)
  if invalid then
    vim.notify('pile: ' .. invalid, vim.log.levels.ERROR)
  else
    edit_apply.apply_aliases(changes)
    edit_apply.apply_tab_names(tab_changes)
  end
  return true
end

--- @param sidebar table Sidebar module providing get_rows() and update()
function M.setup(sidebar)
  local buf = globals.sidebar_buf

  vim.api.nvim_create_autocmd("InsertEnter", {
    buffer = buf,
    callback = function() inserting = true end,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    buffer = buf,
    callback = function()
      inserting = false
      apply_edits(sidebar)
      sidebar.update()
    end,
  })

  vim.api.nvim_create_autocmd("TextChanged", {
    buffer = buf,
    callback = function()
      if apply_edits(sidebar) then
        sidebar.update()
      end
    end,
  })
end

return M
