local config = require("pile.config")
local buffers = require("pile.buffers")
local sidebar = require("pile.windows.sidebar")
local log = require("pile.log")
local session = require("pile.features.session")

local M = {}

local initialized = false
local restore_scheduled = false

local function check_dependencies()
  log.trace("Checking dependencies...")
  if not pcall(require, "window-picker") then
    vim.notify(
      "pile.nvim: s1n7ax/nvim-window-picker is not installed; opening a buffer with several windows will fail. Run :checkhealth pile",
      vim.log.levels.WARN
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
  vim.api.nvim_set_hl(0, "PileAlias", { link = "Special", default = true })
  vim.api.nvim_set_hl(0, "PileTabHeader", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "PileModified", { link = "WarningMsg", default = true })
  vim.api.nvim_set_hl(0, "PileGitModified", { link = "Changed", default = true })
  vim.api.nvim_set_hl(0, "PileGitAdded", { link = "Added", default = true })
  vim.api.nvim_set_hl(0, "PileGitDeleted", { link = "Removed", default = true })
  vim.api.nvim_set_hl(0, "PileGitUntracked", { link = "Comment", default = true })
end

local function setup_autocmds()
  -- Cleared on every call so that calling setup() again does not stack autocmds
  local group = vim.api.nvim_create_augroup("Pile", { clear = true })

  vim.api.nvim_create_autocmd({"WinNew", "WinEnter", "BufEnter", "BufWinEnter"}, {
    group = group,
    pattern = "*",
    callback = function()
      sidebar.schedule_update()
    end
  })

  require("pile.features.aliases").follow_buffer_renames(group, sidebar.schedule_update)
  require("pile.buffers.membership").setup(group)

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    pattern = "*",
    callback = function()
      if config.session and config.session.auto_save then
        session.auto_save()
      end
    end
  })
end

--- Restore the session once per Neovim instance
--- The option is read when the timer fires, so a setup() call that follows the
--- automatic initialization (plugin/pile.lua) can still turn it off.
local function schedule_auto_restore()
  if restore_scheduled then
    return
  end
  restore_scheduled = true

  vim.defer_fn(function()
    if config.session and config.session.auto_restore then
      session.auto_restore()
    end
  end, 100)
end

--- Configure pile.nvim
--- Optional: plugin/pile.lua initializes pile with `vim.g.pile` (or the defaults)
--- when setup() has not been called. Calling it again replaces the configuration.
--- @param opts table|nil Options, merged over `vim.g.pile`
function M.setup(opts)
  opts = vim.tbl_deep_extend("force", vim.g.pile or {}, opts or {})

  if not initialized then
    check_dependencies()
  end
  initialized = true

  config.setup(opts)
  setup_highlights()
  setup_autocmds()
  schedule_auto_restore()
end

--- Initialize with `vim.g.pile` unless setup() already ran
function M.ensure_initialized()
  if not initialized then
    M.setup()
  end
end

function M.is_initialized()
  return initialized
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
  local groups = require('pile.buffers.groups')
  local buffer_list = buffers.get_list()
  local tab_buffers = groups.of_tab(buffer_list)
  local current_buf = buffers.get_current()

  for i, buf in ipairs(tab_buffers) do
    if buf.buf == current_buf then
      local tab = vim.api.nvim_get_current_tabpage()
      if reorder.shift(buffer_list, tab, tab_buffers, i, direction == "up" and -1 or 1) then
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

function M.sort_buffers(opts)
  local reorder = require('pile.features.reorder')
  if not reorder.is_enabled() then
    print("PileSort requires session.preserve_order = true")
    return
  end

  local sort = require('pile.features.sort')
  local sorted = sort.sort(buffers.get_list(), opts.args, opts.bang)
  if not sorted then
    print("Unknown sort key: " .. opts.args .. " (" .. table.concat(sort.KEYS, ", ") .. ")")
    return
  end
  reorder.save_buffer_order(sorted)
  -- Every tab group follows the sorted list again
  require('pile.buffers.membership').clear_orders()
  sidebar.update()
  print("Sorted buffers by " .. opts.args .. (opts.bang and " (reversed)" or ""))
end

function M.prune_aliases()
  local count = require('pile.features.aliases').prune()
  sidebar.update()
  print("Removed " .. count .. " display name(s) of missing files")
end

-- Public functions work without an explicit setup(): the first call initializes pile
for name, fn in pairs(M) do
  if name ~= "setup" and name ~= "ensure_initialized" and name ~= "is_initialized" then
    M[name] = function(...)
      M.ensure_initialized()
      return fn(...)
    end
  end
end

return M
