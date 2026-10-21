--- Session management for pile.nvim
--- Handles saving and restoring buffer lists and window layouts
local session_store = require('pile.storage.session_store')
local log = require('pile.log')
local capture = require('pile.features.session.capture')
local restore_buffers = require('pile.features.session.restore_buffers')
local restore_layout = require('pile.features.session.restore_layout')
local tab_groups = require('pile.features.session.tab_groups')

local M = {}

--- Save current buffers and window layout to a session
--- @param session_name string|nil Session name (defaults to current session)
--- @return boolean Success status
function M.save_current_buffers(session_name)
  session_name = session_name or session_store.get_current_session_name()

  local buffers = capture.buffers()
  if #buffers == 0 then
    log.debug("No buffers to save")
    return false
  end

  local window_layout = capture.window_layout(buffers)
  local ok = session_store.save_session(session_name, buffers, window_layout)
  if ok then
    log.debug(string.format("Saved %d buffers and %d windows to session '%s'",
      #buffers, capture.count_windows(window_layout), session_name))
  end
  return ok
end

--- Restore buffers and window layout from a session
--- @param session_name string|nil Session name (defaults to current session)
--- @return boolean Success status
function M.restore_session(session_name)
  session_name = session_name or session_store.get_current_session_name()

  local session = session_store.get_session(session_name)
  if not session or not session.buffers then
    log.debug("No session found: " .. session_name)
    return false
  end

  require('pile.buffers.membership').clear_orders()
  local buffers = vim.deepcopy(session.buffers)
  table.sort(buffers, function(a, b)
    return a.order < b.order
  end)

  -- Restoring fires a burst of buffer/window events; redraw the sidebar once at the end.
  -- resume() must run even if restoring throws, or the sidebar stays frozen.
  local sidebar = require('pile.windows.sidebar')
  sidebar.suspend()

  local restored_count = 0
  local ok, err = pcall(function()
    restore_buffers.close_empty_nofile()
    local open_before = restore_buffers.listed()
    local buffer_map
    buffer_map, restored_count = restore_buffers.add(buffers)

    log.debug(string.format("Restoring layout with %d windows", capture.count_windows(session.layout)))
    tab_groups.apply(restore_layout.restore(session.layout, buffer_map), buffer_map, open_before)
  end)

  sidebar.resume()

  if not ok then
    log.error("Failed to restore session '" .. session_name .. "': " .. tostring(err))
  end

  if restored_count > 0 then
    log.debug(string.format("Restored %d/%d buffers from session '%s'",
      restored_count, #buffers, session_name))
  end

  return restored_count > 0
end

--- Auto-save current session on VimLeavePre
--- @return boolean Success status
function M.auto_save()
  return M.save_current_buffers()
end

--- Auto-restore session on startup
--- Skips restoration if files were specified on command line
--- @return boolean Success status
function M.auto_restore()
  local args = vim.fn.argv()
  if #args > 0 then
    log.debug("Skipping auto-restore: files specified on command line")
    return false
  end

  return M.restore_session()
end

--- Create a new session with current buffers
--- @param name string Session name
--- @param switch_to boolean Whether to switch to the new session
--- @return boolean Success status
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

--- Switch to a different session
--- Saves current session before switching
--- @param name string Session name to switch to
--- @return boolean Success status
function M.switch_session(name)
  if not session_store.session_exists(name) then
    log.warn("Session does not exist: " .. name)
    return false
  end

  M.save_current_buffers()
  session_store.set_current_session(name)
  return M.restore_session(name)
end

--- Delete a session
--- Cannot delete the current session
--- @param name string Session name to delete
--- @return boolean Success status
function M.delete_session(name)
  if name == session_store.get_current_session_name() then
    log.warn("Cannot delete current session. Switch to another session first.")
    return false
  end

  return session_store.delete_session(name)
end

--- List all available session names
--- @return table List of session names
function M.list_sessions()
  return session_store.list_session_names()
end

--- Get the current session name
--- @return string Current session name
function M.get_current_session_name()
  return session_store.get_current_session_name()
end

--- Get information about a session
--- @param name string Session name
--- @return table|nil Session info {name, buffer_count, last_updated} or nil
function M.get_session_info(name)
  local session = session_store.get_session(name)
  if not session then
    return nil
  end

  local buffers = session.buffers or {}
  return {
    name = session.name,
    buffer_count = #buffers,
    last_updated = session.last_updated
  }
end

return M
