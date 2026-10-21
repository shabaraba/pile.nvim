--- Session management for pile.nvim
--- Handles saving and restoring buffer lists and window layouts
local session_store = require('pile.storage.session_store')
local log = require('pile.log')
local layout = require('pile.windows.layout')

local M = {}

--- Check if a buffer should be saved in the session
--- Listed-but-unloaded buffers count: restore adds buffers lazily, so a buffer
--- the user never opened this session must still survive the next save.
--- @param buf number Buffer handle
--- @return boolean True if buffer should be saved
local function is_saveable_buffer(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and (vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buflisted)
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

--- Collect the split layout of every tab
--- Stores each tab's winlayout() tree with each window's file and size so
--- restore can rebuild the same tabs, horizontal/vertical splits and proportions.
--- Windows without a saveable file (sidebar, terminals, help) are left out, and
--- so are tabs that hold no such window.
--- @return table|nil Layout {version = 3, tabs = {node...}, current_tab} or nil if no window qualifies
local function collect_window_layout()
  local current_tab = vim.api.nvim_get_current_tabpage()
  local is_excluded = function(win)
    return not is_saveable_buffer(vim.api.nvim_win_get_buf(win))
  end

  local tabs, current_index = {}, nil
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local tab_win = vim.api.nvim_tabpage_get_win(tab)

    local function serialize(node)
      if node.type == 'leaf' then
        return {
          type = 'leaf',
          bufpath = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(node.win)),
          row = node.row,
          col = node.col,
          width = node.width,
          height = node.height,
          focused = node.win == tab_win or nil,
        }
      end
      local children = {}
      for _, child in ipairs(node.children) do
        table.insert(children, serialize(child))
      end
      return { type = node.type, children = children }
    end

    local tree = layout.capture(is_excluded, tab)
    if tree then
      table.insert(tabs, serialize(tree))
      if tab == current_tab then
        current_index = #tabs
      end
    end
  end

  if #tabs == 0 then
    return nil
  end
  return { version = 3, tabs = tabs, current_tab = current_index }
end

--- Convert a saved layout into a list of tab trees, accepting older formats
--- version 2 stored a single tree for the current tab; sessions written before
--- split trees were stored hold a plain list of windows, rebuilt side by side.
--- @param saved table Layout as stored in the session
--- @return table[] trees, number|nil current_tab
local function layout_tabs(saved)
  if type(saved) ~= 'table' then
    return {}, nil
  end
  if type(saved.tabs) == 'table' then
    return saved.tabs, tonumber(saved.current_tab)
  end
  if type(saved.tree) == 'table' then
    return { saved.tree }, 1
  end
  if #saved == 0 then
    return {}, nil
  end

  local children = {}
  for _, win_data in ipairs(saved) do
    if type(win_data) == 'table' and win_data.bufpath then
      table.insert(children, { type = 'leaf', bufpath = win_data.bufpath })
    end
  end
  return { { type = 'row', children = children } }, 1
end

--- Count the windows in a saved layout (for logging)
local function count_windows(saved)
  local count = 0
  for _, tree in ipairs((layout_tabs(saved))) do
    if type(tree) == 'table' and tree.type then
      count = count + #layout.leaves(tree)
    end
  end
  return count
end

--- Restore a buffer from a file path
--- The buffer is added but deliberately left unloaded: loading it here would fire
--- BufRead/FileType for every session file, dragging syntax, treesitter and LSP
--- attach into startup. Neovim loads it on first display instead.
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
    -- bufadd() leaves 'buflisted' off, which hides the buffer from :bnext/:bprev
    vim.bo[buf].buflisted = true
    log.trace("Restored buffer: " .. path)
    return true, buf
  end
  return false, nil
end

--- Close all empty nofile buffers
--- Removes buffers with no name and buftype='nofile' (e.g., startup buffers)
--- The sidebar's own scratch buffer matches too and is kept.
local function close_empty_nofile_buffers()
  local sidebar_buf = require('pile.globals').sidebar_buf
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= sidebar_buf and vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      local buftype = vim.bo[buf].buftype
      if name == '' and buftype == 'nofile' then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end
end

--- Drop windows whose file could not be restored and attach buffer handles
--- @return table|nil Normalized tree, or nil if no window is left
local function resolve_tree(node, buffer_map)
  if node.type == 'leaf' then
    local buf = node.bufpath and buffer_map[node.bufpath]
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
      return nil
    end
    return vim.tbl_extend('force', node, { buf = buf })
  end

  if (node.type ~= 'row' and node.type ~= 'col') or type(node.children) ~= 'table' then
    return nil
  end

  local children = {}
  for _, child in ipairs(node.children) do
    local resolved = type(child) == 'table' and resolve_tree(child, buffer_map)
    if resolved then
      table.insert(children, resolved)
    end
  end
  return layout.normalize({ type = node.type, children = children })
end

--- Recreate the splits of a tree inside `win`
--- Siblings are split off first, then each one is subdivided, which yields the
--- same frame structure Neovim reports from winlayout().
--- @return number|nil Window that was focused when the session was saved
local function build_splits(node, win)
  if node.type == 'leaf' then
    vim.api.nvim_win_set_buf(win, node.buf)
    return node.focused and win or nil
  end

  local split_cmd = node.type == 'row' and 'rightbelow vsplit' or 'rightbelow split'
  local wins = { win }
  for i = 2, #node.children do
    vim.api.nvim_set_current_win(wins[i - 1])
    local ok = pcall(vim.cmd, split_cmd)
    if not ok then
      -- Not enough room (E36): keep what fits rather than failing the restore
      break
    end
    wins[i] = vim.api.nvim_get_current_win()
  end

  local focused
  for i, w in ipairs(wins) do
    focused = build_splits(node.children[i], w) or focused
  end
  return focused
end

--- Rebuild one tab's splits in the current tab and size them
--- @return number|nil Window that was focused in this tab when saved
local function restore_tab(tree)
  local focused = build_splits(tree, vim.api.nvim_get_current_win())
  -- Legacy layouts carry no sizes; leave Neovim's equal split in place
  if layout.leaves(tree)[1].width then
    layout.apply(tree)
  end
  return focused or vim.api.nvim_get_current_win()
end

--- Restore window layout
--- Rebuilds the saved tabs and split trees and scales the saved sizes to the
--- current screen.
--- @param saved table|nil Layout information from collect_window_layout
--- @param buffer_map table|nil Mapping from file path to buffer handle
local function restore_window_layout(saved, buffer_map)
  if not buffer_map or type(buffer_map) ~= 'table' then
    log.debug("Invalid buffer_map provided to restore_window_layout")
    return
  end

  local saved_tabs, saved_current = layout_tabs(saved)
  local trees, current_index = {}, nil
  for i, saved_tree in ipairs(saved_tabs) do
    local tree = type(saved_tree) == 'table' and resolve_tree(saved_tree, buffer_map)
    if tree then
      table.insert(trees, tree)
      if i == saved_current then
        current_index = #trees
      end
    end
  end
  if #trees == 0 then
    log.debug("No layout to restore or invalid layout type")
    return
  end

  -- The sidebar must not be the window that survives :only
  local sidebar = require('pile.windows.sidebar')
  local sidebar_was_open = sidebar.is_opened()
  if sidebar_was_open then
    sidebar.close()
  end

  -- Close all tabs and windows except current to avoid "Already only one window" warning
  if #vim.api.nvim_list_tabpages() > 1 then
    vim.cmd('tabonly')
  end
  if #vim.api.nvim_list_wins() > 1 then
    vim.cmd('only')
  end

  local focused = {}
  for i, tree in ipairs(trees) do
    if i > 1 then
      -- :tab split reuses the current buffer instead of creating an empty one
      vim.cmd('tab split')
    end
    focused[i] = restore_tab(tree)
  end

  local target = focused[current_index or 1]
  if target and vim.api.nvim_win_is_valid(target) then
    vim.api.nvim_set_current_win(target)
  end

  if sidebar_was_open then
    sidebar.open()
    if target and vim.api.nvim_win_is_valid(target) then
      vim.api.nvim_set_current_win(target)
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

  local window_layout = collect_window_layout()
  local ok = session_store.save_session(session_name, buffers, window_layout)
  if ok then
    log.debug(string.format("Saved %d buffers and %d windows to session '%s'",
      #buffers, count_windows(window_layout), session_name))
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
    close_empty_nofile_buffers()

    local buffer_map = {}
    for _, buf_data in ipairs(buffers) do
      local restored, buf = restore_buffer(buf_data.path)
      if restored then
        restored_count = restored_count + 1
        buffer_map[buf_data.path] = buf
      end
    end

    log.debug(string.format("Restoring layout with %d windows", count_windows(session.layout)))
    restore_window_layout(session.layout, buffer_map)
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
