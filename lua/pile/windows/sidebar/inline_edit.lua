--- Names edited directly in the sidebar: a buffer line sets its alias, a header line names its tab
local globals = require 'pile.globals'
local edit_apply = require 'pile.windows.sidebar.edit_apply'
local render = require 'pile.windows.sidebar.render'

local M = {}

--- @return boolean changed true when the lines differed from the rows
local function apply_edits(sidebar)
  local entries = edit_apply.entries(sidebar.get_rows(), render.buffer_text)
  local lines = vim.api.nvim_buf_get_lines(globals.sidebar_buf, 0, -1, false)
  local texts = vim.tbl_map(function(entry) return entry.text end, entries)
  if vim.deep_equal(lines, texts) then
    return false
  end

  local changes, tab_changes, invalid = edit_apply.collect(entries, lines, true)
  if invalid then
    edit_apply.notify_error(invalid)
  else
    edit_apply.apply_aliases(changes)
    edit_apply.apply_tab_names(tab_changes)
  end
  return true
end

--- @param sidebar table Sidebar module providing get_rows(), update(), suspend() and resume()
function M.setup(sidebar)
  local buf = globals.sidebar_buf
  -- Undo would bring back names that no longer match the rows
  vim.bo[buf].undolevels = -1

  -- A redraw while typing would overwrite the line being edited
  vim.api.nvim_create_autocmd("InsertEnter", { buffer = buf, callback = sidebar.suspend })

  vim.api.nvim_create_autocmd("InsertLeave", {
    buffer = buf,
    callback = function()
      apply_edits(sidebar)
      sidebar.resume()
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
