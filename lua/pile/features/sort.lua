local history = require('pile.features.history')
local log = require('pile.log')

local M = {}

local sort_mode = 'buffer_number'

function M.set_mode(mode)
  local valid_modes = {
    buffer_number = true,
    mru = true,
    frequency = true,
    score = true
  }

  if not valid_modes[mode] then
    log.warn("Invalid sort mode: " .. mode)
    return false
  end

  sort_mode = mode
  log.debug("Sort mode changed to: " .. mode)
  return true
end

function M.get_mode()
  return sort_mode
end

function M.sort_buffers(buffer_list)
  if sort_mode == 'buffer_number' then
    return M.by_buffer_number(buffer_list)
  elseif sort_mode == 'mru' then
    return M.by_mru(buffer_list)
  elseif sort_mode == 'frequency' then
    return M.by_frequency(buffer_list)
  elseif sort_mode == 'score' then
    return M.by_score(buffer_list)
  end

  return buffer_list
end

function M.by_buffer_number(buffer_list)
  local sorted = vim.deepcopy(buffer_list)
  table.sort(sorted, function(a, b)
    return a.buf < b.buf
  end)
  return sorted
end

function M.by_mru(buffer_list)
  local mru_entries = history.get_mru_list()
  local path_to_timestamp = {}
  
  for _, entry in ipairs(mru_entries) do
    path_to_timestamp[entry.path] = entry.last_access
  end

  local sorted = vim.deepcopy(buffer_list)
  table.sort(sorted, function(a, b)
    local time_a = path_to_timestamp[a.name] or 0
    local time_b = path_to_timestamp[b.name] or 0
    
    if time_a == time_b then
      return a.buf < b.buf
    end
    
    return time_a > time_b
  end)
  
  return sorted
end

function M.by_frequency(buffer_list)
  local entries = history.get_frequent_list()
  local path_to_count = {}
  
  for _, entry in ipairs(entries) do
    path_to_count[entry.path] = entry.access_count
  end

  local sorted = vim.deepcopy(buffer_list)
  table.sort(sorted, function(a, b)
    local count_a = path_to_count[a.name] or 0
    local count_b = path_to_count[b.name] or 0
    
    if count_a == count_b then
      return a.buf < b.buf
    end
    
    return count_a > count_b
  end)
  
  return sorted
end

function M.by_score(buffer_list)
  local sorted = vim.deepcopy(buffer_list)
  table.sort(sorted, function(a, b)
    local score_a = history.get_score(a.name)
    local score_b = history.get_score(b.name)
    
    if score_a == score_b then
      return a.buf < b.buf
    end
    
    return score_a > score_b
  end)
  
  return sorted
end

return M
