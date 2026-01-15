local json_store = require('pile.storage.json_store')
local log = require('pile.log')

local M = {}

local DEFAULT_SESSION = 'default'

local store = nil

local function get_data_path()
  return vim.fn.stdpath('data') .. '/pile/sessions.json'
end

local function get_store()
  if store then
    return store
  end

  store = json_store.new({
    filepath = get_data_path(),
    default_data = {
      version = 1,
      current_session = DEFAULT_SESSION,
      sessions = {}
    }
  })
  return store
end

local function build_buffer_data(buffers)
  local buffer_data = {}
  for i, buf in ipairs(buffers) do
    table.insert(buffer_data, {
      path = buf.path or buf.name,
      order = i - 1
    })
  end
  return buffer_data
end

function M.get_all_sessions()
  local data = get_store().read()
  return data.sessions or {}
end

function M.get_session(name)
  return M.get_all_sessions()[name]
end

function M.get_current_session_name()
  local data = get_store().read()
  return data.current_session or DEFAULT_SESSION
end

function M.get_current_session()
  return M.get_session(M.get_current_session_name())
end

function M.save_session(name, buffers)
  if not name or name == '' then
    log.warn("Session name cannot be empty")
    return false
  end

  local buffer_data = build_buffer_data(buffers)

  return get_store().update(function(data)
    data.sessions = data.sessions or {}
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
  if name == DEFAULT_SESSION then
    log.warn("Cannot delete default session")
    return false
  end

  return get_store().update(function(data)
    if not data.sessions or not data.sessions[name] then
      return data
    end

    data.sessions[name] = nil
    if data.current_session == name then
      data.current_session = DEFAULT_SESSION
    end
    return data
  end)
end

function M.list_session_names()
  local names = vim.tbl_keys(M.get_all_sessions())
  table.sort(names)
  return names
end

function M.session_exists(name)
  return M.get_all_sessions()[name] ~= nil
end

return M
