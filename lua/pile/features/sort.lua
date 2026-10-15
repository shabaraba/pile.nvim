local M = {}

--- Each key maps a buffer entry to a value; buffers are ordered by it ascending
local KEYS = {
  -- buffer.filename may carry a disambiguating directory prefix, so use the real basename
  name = function(buffer) return vim.fn.fnamemodify(buffer.name, ':t'):lower() end,
  path = function(buffer) return buffer.name:lower() end,
  extension = function(buffer) return vim.fn.fnamemodify(buffer.name, ':e'):lower() end,
  filetype = function(buffer) return buffer.filetype or '' end,
  recent = function(buffer)
    local info = vim.fn.getbufinfo(buffer.buf)[1]
    return -(info and info.lastused or 0)
  end,
}

M.KEYS = vim.tbl_keys(KEYS)
table.sort(M.KEYS)

--- Return a sorted copy of the buffer list
--- Ties fall back to the full path so the result does not depend on the input order.
--- @param buffer_list table[]
--- @param key string One of M.KEYS
--- @param reverse boolean|nil
--- @return table[]|nil sorted nil when the key is unknown
function M.sort(buffer_list, key, reverse)
  local value_of = KEYS[key]
  if not value_of then
    return nil
  end

  local entries = {}
  for _, buffer in ipairs(buffer_list) do
    table.insert(entries, { buffer = buffer, value = value_of(buffer) })
  end

  table.sort(entries, function(a, b)
    if a.value ~= b.value then
      return (a.value < b.value) ~= (reverse == true)
    end
    return a.buffer.name < b.buffer.name
  end)

  return vim.tbl_map(function(entry) return entry.buffer end, entries)
end

return M
