local json_store = require('pile.storage.json_store')
local log = require('pile.log')

local M = {}

local function get_data_path()
  local data_dir = vim.fn.stdpath('data') .. '/pile'
  return data_dir .. '/history.json'
end

local store = nil

local function get_store()
  if not store then
    store = json_store.new({
      filepath = get_data_path(),
      default_data = {
        version = 1,
        entries = {}
      }
    })
  end
  return store
end

function M.get_all()
  local data = get_store().read()
  return data.entries or {}
end

function M.get_entry(filepath)
  local entries = M.get_all()
  for _, entry in ipairs(entries) do
    if entry.path == filepath then
      return entry
    end
  end
  return nil
end

function M.record_access(filepath)
  if not filepath or filepath == '' then
    log.debug("Skipping empty filepath")
    return false
  end

  return get_store().update(function(data)
    local entries = data.entries or {}
    local found = false
    local now = os.time()

    for _, entry in ipairs(entries) do
      if entry.path == filepath then
        entry.last_access = now
        entry.access_count = (entry.access_count or 0) + 1
        found = true
        break
      end
    end

    if not found then
      table.insert(entries, {
        path = filepath,
        last_access = now,
        access_count = 1
      })
    end

    data.entries = entries
    return data
  end)
end

function M.remove_entry(filepath)
  return get_store().update(function(data)
    local entries = data.entries or {}
    local new_entries = {}

    for _, entry in ipairs(entries) do
      if entry.path ~= filepath then
        table.insert(new_entries, entry)
      end
    end

    data.entries = new_entries
    return data
  end)
end

function M.clear_all()
  return get_store().write({
    version = 1,
    entries = {}
  })
end

function M.get_stats()
  local entries = M.get_all()
  local total_count = 0
  local oldest = nil
  local newest = nil

  for _, entry in ipairs(entries) do
    total_count = total_count + (entry.access_count or 0)
    if not oldest or entry.last_access < oldest then
      oldest = entry.last_access
    end
    if not newest or entry.last_access > newest then
      newest = entry.last_access
    end
  end

  return {
    total_entries = #entries,
    total_accesses = total_count,
    oldest_access = oldest,
    newest_access = newest
  }
end

return M
