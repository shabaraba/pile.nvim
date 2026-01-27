--- Session management for pile.nvim
--- Handles saving and restoring buffer lists and window layouts
local session_store = require('pile.storage.session_store')
local log = require('pile.log')

local M = {}

--- Check if a buffer should be saved in the session
--- @param buf number Buffer handle
--- @return boolean True if buffer should be saved
local function is_saveable_buffer(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.api.nvim_buf_is_loaded(buf)
    and vim.api.nvim_buf_get_name(buf) ~= ''
    and vim.bo[buf].buftype == ''
end

--- Collect all buffers that should be saved in the session
--- @return table List of buffer information {path, name}
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

--- Check if a window is a normal window (not floating)
--- @param win number Window handle
--- @return boolean True if window is normal
local function is_normal_window(win)
  local config = vim.api.nvim_win_get_config(win)
  return not config.relative or config.relative == ''
end

--- Collect window layout information for all tabs
--- NOTE: Currently stores buffer list per window. Full winlayout() tree restoration
--- is not yet implemented to avoid complexity. Windows are restored as vertical splits.
--- @return table Layout information with buffers per window
local function collect_window_layout()
  local layout = {}

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if is_normal_window(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if is_saveable_buffer(buf) then
        table.insert(layout, {
          bufpath = vim.api.nvim_buf_get_name(buf),
        })
      end
    end
  end

  return layout
end

--- Restore a buffer from a file path
--- @param path string File path to restore
--- @return boolean Success status
--- @return number|nil Buffer handle if successful
local function restore_buffer(path)
  if not path or vim.fn.filereadable(path) ~= 1 then
    log.debug("File not readable: " .. (path or "nil"))
    return false, nil
  end

  local buf = vim.fn.bufadd(path)
  if buf > 0 then
    vim.fn.bufload(buf)
    log.trace("Restored buffer: " .. path)
    return true, buf
  end
  return false, nil
end

--- Close all empty nofile buffers
--- Removes buffers with no name and buftype='nofile' (e.g., startup buffers)
local function close_empty_nofile_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      local buftype = vim.bo[buf].buftype
      if name == '' and buftype == 'nofile' then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end
end

--- Restore window layout
--- NOTE: Currently restores windows as vertical splits only. Full winlayout() tree
--- restoration with proper split directions and sizes is not yet implemented.
--- @param layout table Layout information from collect_window_layout
--- @param buffer_map table Mapping from file path to buffer handle
local function restore_window_layout(layout, buffer_map)
  if not layout or #layout == 0 then
    return
  end

  vim.cmd('only')

  local is_first_window = true
  for _, win_data in ipairs(layout) do
    local buf = buffer_map[win_data.bufpath]
    if buf and vim.api.nvim_buf_is_valid(buf) then
      if not is_first_window then
        vim.cmd('vsplit')
      end
      vim.api.nvim_set_current_buf(buf)
      is_first_window = false
    end
  end
end

--- Save current buffers and window layout to a session
--- @param session_name string|nil Session name (defaults to current session)
--- @return boolean Success status
function M.save_current_buffers(session_name)
  session_name = session_name or session_store.get_current_session_name()

  local buffers = collect_saveable_buffers()
  if #buffers == 0 then
    log.debug("No buffers to save")
    return false
  end

  local layout = collect_window_layout()
  local ok = session_store.save_session(session_name, buffers, layout)
  if ok then
    log.debug(string.format("Saved %d buffers and %d windows to session '%s'",
      #buffers, #layout, session_name))
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

  close_empty_nofile_buffers()

  local buffers = vim.deepcopy(session.buffers)
  table.sort(buffers, function(a, b)
    return a.order < b.order
  end)

  local buffer_map = {}
  local restored_count = 0
  for _, buf_data in ipairs(buffers) do
    local ok, buf = restore_buffer(buf_data.path)
    if ok then
      restored_count = restored_count + 1
      buffer_map[buf_data.path] = buf
    end
  end

  if session.layout and #session.layout > 0 then
    restore_window_layout(session.layout, buffer_map)
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
