local globals = require 'pile.globals'
local edit_apply = require 'pile.windows.sidebar.edit_apply'
local status_watch = require 'pile.windows.sidebar.status_watch'
local wins = require 'pile.windows.sidebar.wins'

local M = {}

-- Edits happen in a throwaway acwrite buffer shown in the sidebar window, so the
-- sidebar buffer itself (keymaps, decorations, options) is never touched.
local state = nil

local function notify_error(message)
  vim.notify('pile: ' .. message, vim.log.levels.ERROR)
end

local function write()
  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local changes, _, invalid = edit_apply.collect(state.entries, lines, false)
  if invalid then
    notify_error(invalid)
    return
  end

  if #changes > 0 then
    local err, keep_editing = edit_apply.apply_file_renames(changes)
    if err then
      notify_error(err)
      if keep_editing then
        return
      end
    end
  end
  -- The edit buffer cannot be swapped out and wiped while its own :write is running
  vim.bo[state.buf].modified = false
  vim.schedule(M.exit)
end

function M.is_editing()
  return state ~= nil
end

--- Show the file paths of the sidebar in an editable buffer; :w renames the edited files, q discards the edits
--- @param sidebar table Sidebar module
function M.enter(sidebar)
  if state then
    return
  end

  local entries, lines = {}, {}
  for _, row in ipairs(sidebar.get_rows()) do
    local text = row.buffer and edit_apply.file_text(row.buffer) or row.group.label
    table.insert(entries, { row = row, text = text })
    table.insert(lines, text)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for i, entry in ipairs(entries) do
    if not entry.row.buffer then
      vim.api.nvim_buf_add_highlight(buf, -1, 'PileTabHeader', i - 1, 0, -1)
    end
  end
  vim.api.nvim_buf_set_name(buf, 'pile://edit/' .. buf)
  vim.bo[buf].buftype = 'acwrite'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].modified = false
  local win = wins.get()
  local cursor = vim.api.nvim_win_get_cursor(win)
  state = { entries = entries, sidebar = sidebar, buf = buf, win = win }

  require('pile.windows.preview').close()
  vim.api.nvim_win_set_buf(win, buf)
  pcall(vim.api.nvim_win_set_cursor, win, cursor)
  vim.wo[win].winbar = ' pile: edit paths  (:w apply, q cancel)'

  vim.api.nvim_create_autocmd("BufWriteCmd", { buffer = buf, callback = write })
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = function() state = nil end,
  })
  vim.keymap.set('n', 'q', M.exit, { buffer = buf, nowait = true, desc = "Discard edits" })
end

function M.exit()
  if not state then
    return
  end
  local sidebar = state.sidebar
  local edit_buf, win = state.buf, state.win
  state = nil

  if vim.api.nvim_buf_is_valid(edit_buf) then
    vim.bo[edit_buf].modified = false
  end
  if vim.api.nvim_win_is_valid(win) and globals.sidebar_buf and vim.api.nvim_buf_is_valid(globals.sidebar_buf) then
    vim.wo[win].winbar = ''
    vim.api.nvim_win_set_buf(win, globals.sidebar_buf)
  end
  if vim.api.nvim_buf_is_valid(edit_buf) then
    vim.api.nvim_buf_delete(edit_buf, { force = true })
  end
  sidebar.update()
  status_watch.refresh_git()
end

return M
