local history_store = require('pile.storage.history_store')
local log = require('pile.log')

local M = {}

function M.record(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    log.debug("Invalid buffer number")
    return false
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if not filepath or filepath == '' then
    log.debug("Buffer has no name")
    return false
  end

  local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
  if buftype ~= '' then
    log.debug("Skipping special buffer type: " .. buftype)
    return false
  end

  return history_store.record_access(filepath)
end

function M.get_mru_list(max_count)
  local entries = history_store.get_all()
  
  table.sort(entries, function(a, b)
    return a.last_access > b.last_access
  end)

  if max_count and max_count > 0 then
    local result = {}
    for i = 1, math.min(max_count, #entries) do
      table.insert(result, entries[i])
    end
    return result
  end

  return entries
end

function M.get_frequent_list(max_count)
  local entries = history_store.get_all()
  
  table.sort(entries, function(a, b)
    if a.access_count == b.access_count then
      return a.last_access > b.last_access
    end
    return a.access_count > b.access_count
  end)

  if max_count and max_count > 0 then
    local result = {}
    for i = 1, math.min(max_count, #entries) do
      table.insert(result, entries[i])
    end
    return result
  end

  return entries
end

function M.get_score(filepath)
  local entry = history_store.get_entry(filepath)
  if not entry then
    return 0
  end

  local recency_weight = 0.7
  local frequency_weight = 0.3

  local now = os.time()
  local age_seconds = now - entry.last_access
  local age_days = age_seconds / 86400
  
  local recency_score = math.max(0, 1 - (age_days / 30))
  local frequency_score = math.min(1, entry.access_count / 100)

  return recency_weight * recency_score + frequency_weight * frequency_score
end

function M.remove(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if not filepath or filepath == '' then
    return false
  end

  return history_store.remove_entry(filepath)
end

function M.clear()
  return history_store.clear_all()
end

function M.stats()
  return history_store.get_stats()
end

return M
