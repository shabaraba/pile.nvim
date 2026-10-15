local globals = require 'pile.globals'
local buffers = require 'pile.buffers'
local log = require 'pile.log'
local render = require 'pile.windows.sidebar.render'
local keymaps = require 'pile.windows.sidebar.keymaps'

local uv = vim.uv or vim.loop

local buffer_list = {}
local SIDEBAR_WIDTH = 35
local augroup = vim.api.nvim_create_augroup("PileSidebar", { clear = true })
local UPDATE_DEBOUNCE_MS = 20
-- oil.nvim finishes its own buffer bookkeeping asynchronously after FileType,
-- so that path has always waited longer before reading buffer state (see 912c3ef).
local OIL_SETTLE_MS = 200

local update_timer = nil
local pending_delay = nil

local M = {}

local function create_sidebar()
  globals.sidebar_buf = vim.api.nvim_create_buf(false, true)
  vim.cmd('topleft vsplit')
  globals.sidebar_win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(globals.sidebar_win, globals.sidebar_buf)
  vim.api.nvim_win_set_width(globals.sidebar_win, SIDEBAR_WIDTH)
end

function M.get_buffer_list()
  return buffer_list
end

function M.open()
  if M.is_opened() then
    print("Sidebar already open.")
    return
  end

  M._is_opening = true

  create_sidebar()
  buffer_list = buffers.get_list()
  render.draw(buffer_list, buffers.get_current())
  keymaps.setup(M)

  vim.api.nvim_create_autocmd("WinLeave", {
    group = augroup,
    buffer = globals.sidebar_buf,
    callback = function()
      require('pile.features.register').clear()
    end,
    desc = "Clear pile register when leaving sidebar"
  })

  M._is_opening = false
end

function M.is_opened()
  return globals.sidebar_win and vim.api.nvim_win_is_valid(globals.sidebar_win)
end

function M.close()
  if M.is_opened() then
    vim.api.nvim_win_close(globals.sidebar_win, true)
    globals.sidebar_win = nil
    globals.sidebar_buf = nil
  else
    print("No sidebar to close.")
  end
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
    if update_timer then
      update_timer:stop()
    end
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

  buffer_list = buffers.get_list()
  render.draw(buffer_list, vim.api.nvim_get_current_buf())

  if globals.sidebar_win and vim.api.nvim_win_is_valid(globals.sidebar_win) then
    vim.api.nvim_win_set_width(globals.sidebar_win, SIDEBAR_WIDTH)
  end
end

vim.api.nvim_create_autocmd({"BufAdd", "BufLeave", "BufEnter"}, {
  pattern = "*",
  callback = function()
    if vim.api.nvim_get_current_buf() ~= globals.sidebar_buf then
      log.debug("Buffer event - updating sidebar")
      M.schedule_update()
    end
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function(ev)
    if ev.match ~= "oil" and ev.match ~= "oilBrowser" then
      M.schedule_update(OIL_SETTLE_MS)
    end
  end
})

return M
