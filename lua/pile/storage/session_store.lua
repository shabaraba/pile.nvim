local json_store = require('pile.storage.json_store')
local log = require('pile.log')

local M = {}

local function get_data_path()
  local data_dir = vim.fn.stdpath('data') .. '/pile'
  return data_dir .. '/sessions.json'
end

local store = nil

local function get_store()
  if not store then
    store = json_store.new({
      filepath = get_data_path(),
      default_data = {
        version = 1,
        current_session = 'default',
        sessions = {}
      }
    })
  end
  return store
end

function M.get_all_sessions()
  local data = get_store().read()
  return data.sessions or {}
end

function M.get_session(name)
  local sessions = M.get_all_sessions()
  return sessions[name]
end

function M.get_current_session_name()
  local data = get_store().read()
  return data.current_session or 'default'
end

function M.get_current_session()
  local name = M.get_current_session_name()
  return M.get_session(name)
end

function M.save_session(name, buffers)
  if not name or name == '' then
    log.warn("Session name cannot be empty")
    return false
  end

  local buffer_data = {}
  for i, buf in ipairs(buffers) do
    table.insert(buffer_data, {
      path = buf.path or buf.name,
      order = i - 1
    })
  end

  return get_store().update(function(data)
    if not data.sessions then
      data.sessions = {}
    end

    data.sessions[name] = {
      name = name,
      buffers = buffer_data,
      last_updated = os.time()
    }

    return data
  end)
end

function M.set_current_session(name)
  return get_store().update(function(data)
    data.current_session = name
    return data
  end)
end

function M.delete_session(name)
  if name == 'default' then
    log.warn("Cannot delete default session")
    return false
  end

  return get_store().update(function(data)
    if data.sessions and data.sessions[name] then
      data.sessions[name] = nil
      
      if data.current_session == name then
        data.current_session = 'default'
      end
    end
    return data
  end)
end

function M.list_session_names()
  local sessions = M.get_all_sessions()
  local names = {}
  for name, _ in pairs(sessions) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

function M.session_exists(name)
  local sessions = M.get_all_sessions()
  return sessions[name] ~= nil
end

return M
