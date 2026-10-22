--- Collects edited sidebar lines and applies them as aliases, tab names or file renames
local config = require 'pile.config'
local session_store = require 'pile.storage.session_store'
local file_rename = require 'pile.features.file_rename'
local tab_names = require 'pile.tab_names'

local M = {}

local function to_absolute(text)
  return vim.fn.fnamemodify(vim.fs.normalize(text), ':p')
end

--- @return string|nil error for an edited header that cannot be renamed
local function check_header(row, edits_headers)
  if not edits_headers then
    return 'Headers cannot be edited here; rename tabs in the sidebar'
  end
  if not row.group.tab then
    return 'The ' .. row.group.label .. ' header cannot be renamed'
  end
end

function M.notify_error(message)
  vim.notify('pile: ' .. message, vim.log.levels.ERROR)
end

--- @param text_of fun(buffer: table): string Text of a buffer line; headers show their group label
--- @return table[] entries {row, text}
function M.entries(rows, text_of)
  return vim.tbl_map(function(row)
    return { row = row, text = row.buffer and text_of(row.buffer) or row.group.label }
  end, rows)
end

--- A buffer shown in several groups takes one name; its edited rows must agree
--- @param entries table[] {row, text} as shown before editing, from M.entries()
--- @param lines string[] Edited lines
--- @param edits_headers boolean Whether header lines may be changed
--- @return table[]|nil changes {buffer, text}
--- @return table[]|nil tab_changes {tab, text}
--- @return string|nil error
function M.collect(entries, lines, edits_headers)
  if #lines ~= #entries then
    return nil, nil, 'Adding or removing lines is not supported; edit the names in place'
  end

  local changes, tab_changes, by_buf = {}, {}, {}
  for i, entry in ipairs(entries) do
    local text, row = vim.trim(lines[i]), entry.row
    if text ~= entry.text then
      if not row.buffer then
        local invalid = check_header(row, edits_headers)
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

--- @param changes table[] {buffer, text}; an empty text or the file name removes the alias
function M.apply_aliases(changes)
  local updates = {}
  for _, change in ipairs(changes) do
    local buffer = change.buffer
    local cleared = change.text == '' or change.text == buffer.filename
    updates[buffer.name] = not cleared and change.text or false
  end
  if next(updates) then
    session_store.update_aliases(updates)
  end
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

--- @param changes table[] {buffer, text}
--- @return string|nil error
--- @return boolean keep_editing true when nothing was changed and the edits can be fixed
function M.apply_file_renames(changes)
  local renames = {}
  for _, change in ipairs(changes) do
    if change.text == '' then
      return 'A file name cannot be empty', true
    end
    local buffer = change.buffer
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

--- @param changes table[] {tab, text}; an empty text or the default label removes the name
function M.apply_tab_names(changes)
  for _, change in ipairs(changes) do
    if vim.api.nvim_tabpage_is_valid(change.tab) then
      local cleared = change.text == tab_names.default_label(change.tab)
      tab_names.set(change.tab, not cleared and change.text or nil)
    end
  end
  if #changes > 0 then
    vim.cmd.redrawtabline()
  end
end

return M
