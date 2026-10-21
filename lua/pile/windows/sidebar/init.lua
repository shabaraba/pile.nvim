local globals = require 'pile.globals'
local buffers = require 'pile.buffers'
local groups = require 'pile.buffers.groups'
local log = require 'pile.log'
local preview = require 'pile.windows.preview'
local render = require 'pile.windows.sidebar.render'
local keymaps = require 'pile.windows.sidebar.keymaps'
local status_watch = require 'pile.windows.sidebar.status_watch'
local wins = require 'pile.windows.sidebar.wins'

local uv = vim.uv or vim.loop

local buffer_list = {}
local rows = {}
local opened = false
local augroup = vim.api.nvim_create_augroup("PileSidebar", { clear = true })
local UPDATE_DEBOUNCE_MS = 20
-- oil.nvim finishes its own buffer bookkeeping asynchronously after FileType,
-- so that path has always waited longer before reading buffer state (see 912c3ef).
local OIL_SETTLE_MS = 200

local update_timer = nil
local pending_delay = nil

local M = {}

local function create_buffer()
  globals.sidebar_buf = vim.api.nvim_create_buf(false, true)
  keymaps.setup(M)

  vim.api.nvim_create_autocmd("WinLeave", {
    group = augroup,
    buffer = globals.sidebar_buf,
    callback = function()
      require('pile.features.register').clear()
    end,
    desc = "Clear pile register when leaving sidebar"
  })

  preview.attach(M)
end

local function refresh()
  buffer_list = buffers.get_list()
  rows = groups.rows(groups.build(buffer_list))
  render.draw(rows, vim.api.nvim_get_current_buf())
end

--- Whole buffer list in stored order (each buffer once)
function M.get_buffer_list()
  return buffer_list
end

--- One entry per sidebar line; see groups.rows()
function M.get_rows()
  return rows
end

function M.get_row_at_cursor()
  local win = wins.get()
  return win and rows[vim.api.nvim_win_get_cursor(win)[1]]
end

--- @return table|nil nil on a group header
function M.get_buffer_at_cursor()
  local row = M.get_row_at_cursor()
  return row and row.buffer
end

function M.open()
  if M.is_opened() then
    print("Sidebar already open.")
    return
  end

  M._is_opening = true
  opened = true
  create_buffer()
  wins.open(globals.sidebar_buf)
  refresh()
  M._is_opening = false
  status_watch.refresh_git()
end

function M.is_opened()
  return opened
end

function M.close()
  if not M.is_opened() then
    print("No sidebar to close.")
    return
  end

  opened = false
  preview.close()
  local current = vim.api.nvim_get_current_tabpage()
  for tab in pairs(wins.all()) do
    if tab ~= current then
      wins.close(tab)
    end
  end
  wins.close(current)

  if globals.sidebar_buf and vim.api.nvim_buf_is_valid(globals.sidebar_buf) then
    vim.api.nvim_buf_delete(globals.sidebar_buf, { force = true })
  end
  globals.sidebar_buf = nil
end

function M.toggle()
  if M.is_opened() then
    M.close()
  else
    M.open()
  end
end

--- Suspend sidebar updates
--- Bulk operations (session restore) fire hundreds of buffer/window events;
--- rebuilding the sidebar for each one is wasted work.
function M.suspend()
  M._suspended = true
end

--- Resume sidebar updates and redraw once
function M.resume()
  M._suspended = false
  pending_delay = nil
  M.update()
  status_watch.refresh_git()
end

--- Request an update, coalescing bursts of events into a single redraw
--- @param delay number|nil Milliseconds to wait; defaults to UPDATE_DEBOUNCE_MS
function M.schedule_update(delay)
  if M._suspended or M._is_opening then
    return
  end

  delay = delay or UPDATE_DEBOUNCE_MS
  -- A pending longer wait must not be cut short by a later quick event
  if pending_delay and pending_delay > delay then
    delay = pending_delay
  end
  pending_delay = delay

  if not update_timer then
    update_timer = uv.new_timer()
  end
  update_timer:stop()
  update_timer:start(delay, 0, vim.schedule_wrap(function()
    pending_delay = nil
    M.update()
  end))
end

function M.update()
  if M._is_opening or M._suspended then
    return
  end

  if not globals.sidebar_buf or not vim.api.nvim_buf_is_valid(globals.sidebar_buf) then
    return
  end

  refresh()
  wins.fix_widths()
end

require('pile.windows.sidebar.tab_watch').setup(M, augroup)

vim.api.nvim_create_autocmd({"BufAdd", "BufLeave", "BufEnter"}, {
  group = augroup,
  pattern = "*",
  callback = function()
    if vim.api.nvim_get_current_buf() ~= globals.sidebar_buf then
      log.debug("Buffer event - updating sidebar")
      M.schedule_update()
    end
  end
})

status_watch.setup(M)

vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = "*",
  callback = function(ev)
    -- Unlisted buffers (preview scratch, plugin UIs) never appear in the sidebar
    if vim.bo[ev.buf].buflisted and ev.match ~= "oil" and ev.match ~= "oilBrowser" then
      M.schedule_update(OIL_SETTLE_MS)
    end
  end
})

return M
