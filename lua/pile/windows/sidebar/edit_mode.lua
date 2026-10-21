local globals = require 'pile.globals'
local edit_apply = require 'pile.windows.sidebar.edit_apply'
local status_watch = require 'pile.windows.sidebar.status_watch'
local wins = require 'pile.windows.sidebar.wins'

local M = {}

local MODES = edit_apply.MODES

-- Edits happen in a throwaway acwrite buffer shown in the sidebar window, so the
-- sidebar buffer itself (keymaps, decorations, options) is never touched.
local state = nil

--- @return string|nil error for an edited header that cannot be renamed
local function check_header(row)
  if not MODES[state.kind].edits_headers then
    return 'Headers cannot be edited here; rename tabs with `a`'
  end
  if not row.group.tab then
    return 'The ' .. row.group.label .. ' header cannot be renamed'
  end
end

--- A buffer shown in several groups takes one name; its edited rows must agree
--- @return table[]|nil changes {buffer, text}
--- @return table[]|nil tab_changes {tab, text}
--- @return string|nil error
local function collect_changes()
  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  if #lines ~= #state.entries then
    return nil, nil, 'Adding or removing lines is not supported; edit the names in place'
  end

  local changes, tab_changes, by_buf = {}, {}, {}
  for i, entry in ipairs(state.entries) do
    local text, row = vim.trim(lines[i]), entry.row
    if text ~= entry.text then
      if not row.buffer then
        local invalid = check_header(row)
        if invalid then
          return nil, nil, invalid
        end
        table.insert(tab_changes, { tab = row.group.tab, text = text })
      elseif not by_buf[row.buffer.buf] then
        by_buf[row.buffer.buf] = text
        table.insert(changes, { buffer = row.buffer, text = text })
      elseif by_buf[row.buffer.buf] ~= text then
        return nil, nil, string.format('%s has different names in its rows', entry.text)
      end
    end
  end
  return changes, tab_changes, nil
end

local function notify_error(message)
  vim.notify('pile: ' .. message, vim.log.levels.ERROR)
end

local function write()
  local changes, tab_changes, invalid = collect_changes()
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
  edit_apply.apply_tab_names(tab_changes)
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
  for _, row in ipairs(sidebar.get_rows()) do
    local text = row.buffer and MODES[kind].text(row.buffer) or row.group.label
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
  state = { kind = kind, entries = entries, sidebar = sidebar, buf = buf, win = win }

  require('pile.windows.preview').close()
  vim.api.nvim_win_set_buf(win, buf)
  pcall(vim.api.nvim_win_set_cursor, win, cursor)
  vim.wo[win].winbar = string.format(' pile: edit %s  (:w apply, q cancel)', kind == 'file' and 'paths' or 'names')

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
