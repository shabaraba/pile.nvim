local globals = require 'pile.globals'
local config = require 'pile.config'
local session_store = require 'pile.storage.session_store'
local file_rename = require 'pile.features.file_rename'
local status_watch = require 'pile.windows.sidebar.status_watch'

local M = {}

-- Edits happen in a throwaway acwrite buffer shown in the sidebar window, so the
-- sidebar buffer itself (keymaps, decorations, options) is never touched.
local state = nil

local function to_absolute(text)
  return vim.fn.fnamemodify(vim.fs.normalize(text), ':p')
end

local function apply_aliases(changes)
  local updates = {}
  for _, change in ipairs(changes) do
    local buffer = change.entry.buffer
    local cleared = change.text == '' or change.text == buffer.filename
    updates[buffer.name] = not cleared and change.text or false
  end
  session_store.update_aliases(updates)
  return nil, false
end

local function confirm_renames(renames)
  if not config.rename.confirm then
    return true
  end
  local lines = {}
  for _, change in ipairs(renames) do
    table.insert(lines, vim.fn.fnamemodify(change.from, ':.') .. ' -> ' .. vim.fn.fnamemodify(change.to, ':.'))
  end
  return vim.fn.confirm('Rename files?\n' .. table.concat(lines, '\n'), '&Yes\n&No', 2) == 1
end

--- @return string|nil error
--- @return boolean keep_editing true when nothing was changed and the edits can be fixed
local function apply_file_renames(changes)
  local renames = {}
  for _, change in ipairs(changes) do
    if change.text == '' then
      return 'A file name cannot be empty', true
    end
    local buffer = change.entry.buffer
    table.insert(renames, { buf = buffer.buf, from = buffer.name, to = to_absolute(change.text) })
  end

  local invalid = file_rename.validate(renames)
  if invalid then
    return invalid, true
  end
  if not confirm_renames(renames) then
    return 'Rename cancelled', true
  end
  return file_rename.apply(renames), false
end

local MODES = {
  alias = {
    text = function(buffer) return buffer.alias or buffer.filename end,
    apply = apply_aliases,
  },
  file = {
    text = function(buffer) return vim.fn.fnamemodify(buffer.name, ':.') end,
    apply = apply_file_renames,
  },
}

local function collect_changes()
  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  if #lines ~= #state.entries then
    return nil, 'Adding or removing lines is not supported; edit the names in place'
  end

  local changes = {}
  for i, entry in ipairs(state.entries) do
    local text = vim.trim(lines[i])
    if text ~= entry.text then
      table.insert(changes, { entry = entry, text = text })
    end
  end
  return changes, nil
end

local function notify_error(message)
  vim.notify('pile: ' .. message, vim.log.levels.ERROR)
end

local function write()
  local changes, invalid = collect_changes()
  if invalid then
    notify_error(invalid)
    return
  end

  if #changes > 0 then
    local err, keep_editing = MODES[state.kind].apply(changes)
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

--- Show an editable copy of the sidebar; :w applies the edited names, q discards them
--- @param sidebar table Sidebar module
--- @param kind "alias"|"file"
function M.enter(sidebar, kind)
  if state or not MODES[kind] then
    return
  end

  local entries, lines = {}, {}
  for _, buffer in ipairs(sidebar.get_buffer_list()) do
    local text = MODES[kind].text(buffer)
    table.insert(entries, { buffer = buffer, text = text })
    table.insert(lines, text)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(buf, 'pile://edit/' .. buf)
  vim.bo[buf].buftype = 'acwrite'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].modified = false
  state = { kind = kind, entries = entries, sidebar = sidebar, buf = buf }

  require('pile.windows.preview').close()
  vim.api.nvim_win_set_buf(globals.sidebar_win, buf)
  vim.wo[globals.sidebar_win].winbar = string.format(' pile: edit %s  (:w apply, q cancel)', kind == 'file' and 'paths' or 'names')

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
  local edit_buf = state.buf
  state = nil

  if vim.api.nvim_buf_is_valid(edit_buf) then
    vim.bo[edit_buf].modified = false
  end
  if globals.sidebar_win and vim.api.nvim_win_is_valid(globals.sidebar_win) then
    vim.wo[globals.sidebar_win].winbar = ''
    vim.api.nvim_win_set_buf(globals.sidebar_win, globals.sidebar_buf)
  end
  if vim.api.nvim_buf_is_valid(edit_buf) then
    vim.api.nvim_buf_delete(edit_buf, { force = true })
  end
  sidebar.update()
  status_watch.refresh_git()
end

return M
