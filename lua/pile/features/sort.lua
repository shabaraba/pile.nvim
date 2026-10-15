local reorder = require('pile.features.reorder')

local M = {}

local function basename(buffer)
  return vim.fn.fnamemodify(buffer.name, ':t'):lower()
end

local function extension(buffer)
  return vim.fn.fnamemodify(buffer.name, ':e'):lower()
end

local function last_used(buffer)
  local info = vim.fn.getbufinfo(buffer.buf)[1]
  return info and info.lastused or 0
end

local function filetype(buffer)
  return vim.api.nvim_buf_is_valid(buffer.buf) and vim.bo[buffer.buf].filetype or ''
end

--- Each key maps a buffer to a value; buffers are ordered by it ascending
local KEYS = {
  name = basename,
  path = function(buffer) return buffer.name:lower() end,
  extension = extension,
  filetype = filetype,
  recent = function(buffer) return -last_used(buffer) end,
}

function M.keys()
  local names = vim.tbl_keys(KEYS)
  table.sort(names)
  return names
end

--- Return a sorted copy of the buffer list
--- Ties fall back to the full path so the result does not depend on the input order.
--- @param buffer_list table[]
--- @param key string One of M.keys()
--- @param reverse boolean|nil
--- @return table[]|nil sorted nil when the key is unknown
function M.sort(buffer_list, key, reverse)
  local value_of = KEYS[key]
  if not value_of then
    return nil
  end

  local entries = {}
  for _, buffer in ipairs(buffer_list) do
    table.insert(entries, { buffer = buffer, value = value_of(buffer), path = buffer.name })
  end

  table.sort(entries, function(a, b)
    if a.value ~= b.value then
      if reverse then
        return a.value > b.value
      end
      return a.value < b.value
    end
    return a.path < b.path
  end)

  local sorted = {}
  for _, entry in ipairs(entries) do
    table.insert(sorted, entry.buffer)
  end
  return sorted
end

--- Sort the buffers and persist the result as the manual order
--- @return boolean ok
function M.apply(buffer_list, key, reverse)
  local sorted = M.sort(buffer_list, key, reverse)
  if not sorted then
    return false
  end
  reorder.save_buffer_order(sorted)
  return true
end

return M
