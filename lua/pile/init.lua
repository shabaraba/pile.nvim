local config = require("pile.config")
local buffers = require("pile.buffers")
local sidebar = require("pile.windows.sidebar")
local log = require("pile.log")
local session = require("pile.features.session")

local M = {}

local function check_dependencies()
  log.trace("Checking dependencies...")
  local has_nui = pcall(require, "nui.popup")
  if not has_nui then
    log.error("Required dependency nui.nvim not found. Please install it with your plugin manager.")
    vim.notify(
      "pile.nvim requires nui.nvim to be installed. Please add it to your plugin manager.",
      vim.log.levels.ERROR
    )
    return false
  end
  log.trace("All dependencies found")
  return true
end

local function setup_highlights()
  vim.api.nvim_set_hl(0, "SidebarCurrentBuffer", {
    bg = config.buffer.highlight.current.bg,
    fg = config.buffer.highlight.current.fg,
  })
  vim.api.nvim_set_hl(0, "SelectedWindow", {
    bg = "Red",
    fg = "White",
  })
end

local function setup_autocmds()
  vim.api.nvim_create_autocmd({"WinNew", "WinEnter"}, {
    pattern = "*",
    callback = function()
      sidebar.update()
    end
  })

  vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
    pattern = "*",
    callback = function()
      sidebar.update()
    end
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    pattern = "*",
    callback = function()
      if config.session and config.session.auto_save then
        session.auto_save()
      end
    end
  })
end

local function setup_commands()
  vim.api.nvim_create_user_command("PileToggle", M.toggle_sidebar, { desc = "toggle pile window" })
  vim.api.nvim_create_user_command("PileGoToNextBuffer", M.switch_to_next_buffer, { desc = "go to next buffer" })
  vim.api.nvim_create_user_command("PileGoToPrevBuffer", M.switch_to_prev_buffer, { desc = "go to prev buffer" })

  vim.api.nvim_create_user_command("PileSaveSession", M.save_session, {
    nargs = "?",
    desc = "save current buffers to session"
  })
  vim.api.nvim_create_user_command("PileRestoreSession", M.restore_session, {
    nargs = "?",
    complete = function() return session.list_sessions() end,
    desc = "restore session"
  })
  vim.api.nvim_create_user_command("PileCreateSession", M.create_session, {
    nargs = 1,
    desc = "create new session with name"
  })
  vim.api.nvim_create_user_command("PileSwitchSession", M.switch_session, {
    nargs = 1,
    complete = function() return session.list_sessions() end,
    desc = "switch to session"
  })
  vim.api.nvim_create_user_command("PileDeleteSession", M.delete_session, {
    nargs = 1,
    complete = function() return session.list_sessions() end,
    desc = "delete session"
  })
  vim.api.nvim_create_user_command("PileListSessions", M.list_sessions, {
    desc = "list all sessions"
  })

  vim.api.nvim_create_user_command("PileMoveBufferUp", M.move_buffer_up, {
    desc = "move current buffer up in sidebar"
  })
  vim.api.nvim_create_user_command("PileMoveBufferDown", M.move_buffer_down, {
    desc = "move current buffer down in sidebar"
  })
end

function M.setup(opts)
  if not check_dependencies() then
    return
  end

  config.setup(opts)
  setup_highlights()
  setup_autocmds()
  setup_commands()

  if config.session and config.session.auto_restore then
    vim.defer_fn(function()
      session.auto_restore()
    end, 100)
  end
end

function M.toggle_sidebar()
  sidebar.toggle()
end

function M.switch_to_next_buffer()
  buffers.next()
end

function M.switch_to_prev_buffer()
  buffers.prev()
end

local function get_session_name(opts)
  if not opts or not opts.args then
    return nil
  end
  return opts.args ~= "" and opts.args or nil
end

function M.save_session(opts)
  local name = get_session_name(opts)
  if session.save_current_buffers(name) then
    print("Session saved: " .. (name or session.get_current_session_name()))
  else
    print("Failed to save session")
  end
end

function M.restore_session(opts)
  local name = get_session_name(opts)
  if session.restore_session(name) then
    sidebar.update()
    print("Session restored: " .. (name or session.get_current_session_name()))
  else
    print("No session to restore")
  end
end

function M.create_session(opts)
  if session.create_session(opts.args, false) then
    print("Session created: " .. opts.args)
  else
    print("Failed to create session (may already exist)")
  end
end

function M.switch_session(opts)
  if session.switch_session(opts.args) then
    sidebar.update()
    print("Switched to session: " .. opts.args)
  else
    print("Failed to switch session")
  end
end

function M.delete_session(opts)
  if session.delete_session(opts.args) then
    print("Session deleted: " .. opts.args)
  else
    print("Failed to delete session")
  end
end

function M.list_sessions()
  local sessions = session.list_sessions()
  local current = session.get_current_session_name()

  print("=== Pile Sessions ===")
  if #sessions == 0 then
    print("No sessions found")
  else
    for _, name in ipairs(sessions) do
      local info = session.get_session_info(name)
      local marker = (name == current) and "*" or " "
      if info then
        print(string.format("%s %s (%d buffers, updated: %s)",
          marker, name, info.buffer_count,
          os.date("%Y-%m-%d %H:%M", info.last_updated)))
      end
    end
  end
end

local function move_buffer(direction)
  local reorder = require('pile.features.reorder')
  local buffer_list = buffers.get_list()
  local current_buf = buffers.get_current()

  for i, buf in ipairs(buffer_list) do
    if buf.buf == current_buf then
      local target = direction == "up" and i - 1 or i + 1
      if target >= 1 and target <= #buffer_list then
        local reordered = reorder.move_buffer(i, target, buffer_list)
        reorder.save_buffer_order(reordered)
        sidebar.update()
        print("Buffer moved " .. direction)
        return
      end
      break
    end
  end
  print("Cannot move buffer " .. direction)
end

function M.move_buffer_up()
  move_buffer("up")
end

function M.move_buffer_down()
  move_buffer("down")
end

return M
