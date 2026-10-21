--- Sidebar cut/yank/paste register
--- Operations take sidebar rows: a buffer in one tab's group (or the
--- unassigned group), so cutting takes the buffer out of that tab only.
local log = require('pile.log')
local membership = require('pile.buffers.membership')
local transfer = require('pile.features.transfer')

local M = {}

local register = {}

local function store_rows(rows)
  register = {}
  local seen = {}
  for _, row in ipairs(rows) do
    if not seen[row.buffer.buf] then
      seen[row.buffer.buf] = true
      table.insert(register, { path = row.buffer.name })
    end
  end
end

--- Buffers that belong to no tab once `rows` are taken out of their tabs
local function orphans(rows)
  local leaving = {}
  for _, row in ipairs(rows) do
    local buf = row.buffer.buf
    leaving[buf] = leaving[buf] or {}
    if row.group.tab then
      leaving[buf][row.group.tab] = true
    end
  end

  local result = {}
  for buf, tabs in pairs(leaving) do
    local remaining = vim.tbl_filter(function(tab) return not tabs[tab] end, membership.tabs_of(buf))
    if #remaining == 0 and vim.api.nvim_buf_is_valid(buf) then
      table.insert(result, buf)
    end
  end
  return result
end

--- @return boolean false when the user cancels
local function confirm_unsaved(bufs)
  local modified = vim.tbl_filter(function(buf) return vim.bo[buf].modified end, bufs)
  if #modified == 0 then
    return true
  end

  local names = vim.tbl_map(vim.api.nvim_buf_get_name, modified)
  local choice = vim.fn.confirm(
    string.format("Save changes to %d buffer(s)?\n%s", #modified, table.concat(names, "\n")),
    "&Save\n&Discard\n&Cancel",
    3
  )
  if choice == 1 then
    for _, buf in ipairs(modified) do
      vim.api.nvim_buf_call(buf, function()
        vim.cmd.write({ bang = true })
      end)
    end
  end
  return choice == 1 or choice == 2
end

--- Take each row's buffer out of its tab; a buffer left in no tab is deleted
--- @param rows table[] Buffer rows; see groups.rows()
function M.cut(rows)
  if not rows or #rows == 0 then
    log.debug("No buffers to cut")
    return false
  end

  local deleting = orphans(rows)
  if not confirm_unsaved(deleting) then
    log.debug("Cut operation cancelled by user")
    return false
  end

  store_rows(rows)
  for _, row in ipairs(rows) do
    if row.group.tab then
      transfer.detach(row.group.tab, row.buffer.buf)
    end
  end
  for _, buf in ipairs(deleting) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  log.debug(string.format("Cut %d buffer(s)", #register))
  return true
end

--- @param rows table[] Buffer rows; see groups.rows()
function M.yank(rows)
  if not rows or #rows == 0 then
    log.debug("No buffers to yank")
    return false
  end

  store_rows(rows)
  log.debug(string.format("Yanked %d buffer(s)", #register))
  return true
end

--- Buffer entries for the register's files, re-adding (and listing) deleted ones
--- No tab takes them in yet; see transfer.place().
--- @return table[]
function M.paste()
  local entries = {}
  membership.quietly(function()
    for _, item in ipairs(register) do
      local buf = vim.fn.bufadd(item.path)
      if buf > 0 then
        vim.fn.bufload(buf)
        vim.bo[buf].buflisted = true
        table.insert(entries, {
          buf = buf,
          name = item.path,
          filename = vim.fn.fnamemodify(item.path, ":t"),
        })
        log.trace("Pasted buffer: " .. item.path)
      end
    end
  end)
  log.debug(string.format("Pasted %d buffer(s)", #entries))
  return entries
end

function M.clear()
  register = {}
  log.debug("Register cleared")
end

function M.is_empty()
  return #register == 0
end

return M
