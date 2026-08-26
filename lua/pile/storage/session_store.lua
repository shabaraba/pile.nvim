local json_store = require('pile.storage.json_store')
local log = require('pile.log')
local git_utils = require('pile.utils.git')

local M = {}

local DEFAULT_SESSION = 'default'

local store_cache = {}
local project_id_cache = {}

local function string_hash(str)
  local hash = 0
  for i = 1, #str do
    hash = (hash * 31 + string.byte(str, i)) % 0x7FFFFFFF
  end
  return string.format("%08x", hash)
end

--- Resolve the project id for a working directory
--- Memoized per cwd: get_git_root spawns a git subprocess, and this runs on
--- every store access (which happens on every sidebar update).
local function get_project_id(cwd)
  local cached = project_id_cache[cwd]
  if cached then
    return cached
  end

  local project_id = 'global'
  local git_root = git_utils.get_git_root(cwd)
  if git_root then
    project_id = vim.fn.fnamemodify(git_root, ':t') .. '-' .. string_hash(git_root)
  end

  project_id_cache[cwd] = project_id
  return project_id
end

local function get_data_path()
  local project_id = get_project_id(vim.fn.getcwd())
  return vim.fn.stdpath('data') .. '/pile/sessions-' .. project_id .. '.json'
end

local function get_store()
  local data_path = get_data_path()

  if store_cache[data_path] then
    return store_cache[data_path]
  end

  local new_store = json_store.new({
    filepath = data_path,
    default_data = {
      version = 1,
      current_session = DEFAULT_SESSION,
      sessions = {}
    }
  })

  store_cache[data_path] = new_store
  return new_store
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

--- Clear memoized project ids
--- Exposed so a changed git worktree (e.g. after :tcd) can be picked up.
function M.clear_cache()
  project_id_cache = {}
  for _, store in pairs(store_cache) do
    store.invalidate()
  end
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

function M.save_session(name, buffers, layout)
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
      layout = layout or {},
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
