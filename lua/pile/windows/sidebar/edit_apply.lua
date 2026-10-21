--- What each edit mode shows for a buffer and how it applies the edited names
local config = require 'pile.config'
local session_store = require 'pile.storage.session_store'
local file_rename = require 'pile.features.file_rename'
local tab_names = require 'pile.tab_names'

local M = {}

local function to_absolute(text)
  return vim.fn.fnamemodify(vim.fs.normalize(text), ':p')
end

local function apply_aliases(changes)
  local updates = {}
  for _, change in ipairs(changes) do
    local buffer = change.buffer
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

M.MODES = {
  alias = {
    text = function(buffer) return buffer.alias or buffer.filename end,
    apply = apply_aliases,
    edits_headers = true,
  },
  file = {
    text = function(buffer) return vim.fn.fnamemodify(buffer.name, ':.') end,
    apply = apply_file_renames,
  },
}

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
