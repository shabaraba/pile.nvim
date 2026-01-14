local session_store = require('pile.storage.session_store')
local log = require('pile.log')

local M = {}

local function is_saveable_buffer(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.api.nvim_buf_is_loaded(buf)
    and vim.api.nvim_buf_get_name(buf) ~= ''
    and vim.bo[buf].buftype == ''
end

local function collect_saveable_buffers()
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_saveable_buffer(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      table.insert(buffers, { path = name, name = name })
    end
  end
  return buffers
end

local function restore_buffer(path)
  if not path or vim.fn.filereadable(path) ~= 1 then
    log.debug("File not readable: " .. (path or "nil"))
    return false
  end

  local buf = vim.fn.bufadd(path)
  if buf > 0 then
    vim.fn.bufload(buf)
    log.trace("Restored buffer: " .. path)
    return true
  end
  return false
end

function M.save_current_buffers(session_name)
  session_name = session_name or session_store.get_current_session_name()

  local buffers = collect_saveable_buffers()
  if #buffers == 0 then
    log.debug("No buffers to save")
    return false
  end

  local ok = session_store.save_session(session_name, buffers)
  if ok then
    log.debug(string.format("Saved %d buffers to session '%s'", #buffers, session_name))
  end
  return ok
end

function M.restore_session(session_name)
  session_name = session_name or session_store.get_current_session_name()

  local session = session_store.get_session(session_name)
  if not session or not session.buffers then
    log.debug("No session found: " .. session_name)
    return false
  end

  local buffers = session.buffers
  table.sort(buffers, function(a, b)
    return a.order < b.order
  end)

  local restored_count = 0
  for _, buf_data in ipairs(buffers) do
    if restore_buffer(buf_data.path) then
      restored_count = restored_count + 1
    end
  end

  if restored_count > 0 then
    log.debug(string.format("Restored %d/%d buffers from session '%s'",
      restored_count, #buffers, session_name))
  end

  return restored_count > 0
end

function M.auto_save()
  return M.save_current_buffers()
end

function M.auto_restore()
  return M.restore_session()
end

function M.create_session(name, switch_to)
  if session_store.session_exists(name) then
    log.warn("Session already exists: " .. name)
    return false
  end

  local ok = M.save_current_buffers(name)
  if ok and switch_to then
    session_store.set_current_session(name)
  end
  return ok
end

function M.switch_session(name)
  if not session_store.session_exists(name) then
    log.warn("Session does not exist: " .. name)
    return false
  end

  M.save_current_buffers()
  session_store.set_current_session(name)
  return M.restore_session(name)
end

function M.delete_session(name)
  if name == session_store.get_current_session_name() then
    log.warn("Cannot delete current session. Switch to another session first.")
    return false
  end

  return session_store.delete_session(name)
end

function M.list_sessions()
  return session_store.list_session_names()
end

function M.get_current_session_name()
  return session_store.get_current_session_name()
end

function M.get_session_info(name)
  local session = session_store.get_session(name)
  if not session then
    return nil
  end

  return {
    name = session.name,
    buffer_count = #session.buffers,
    last_updated = session.last_updated
  }
end

return M
