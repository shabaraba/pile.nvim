local globals = require 'pile.globals'
local buffers = require 'pile.buffers'
local log = require 'pile.log'
local preview = require 'pile.windows.preview'
local render = require 'pile.windows.sidebar.render'
local keymaps = require 'pile.windows.sidebar.keymaps'
local status_watch = require 'pile.windows.sidebar.status_watch'
local layout = require 'pile.windows.layout'

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

-- Split layout around the last open, so close can restore the exact sizes
-- instead of re-scaling (and accumulating rounding drift) when nothing changed.
local layout_before_open = nil
local layout_after_open = nil

local M = {}

local function is_sidebar_win(win)
  return win == globals.sidebar_win
end

local function create_sidebar()
  local before = layout.capture()

  globals.sidebar_buf = vim.api.nvim_create_buf(false, true)
  layout.without_equalalways(function()
    vim.cmd('topleft ' .. SIDEBAR_WIDTH .. 'vsplit')
  end)
  globals.sidebar_win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(globals.sidebar_win, globals.sidebar_buf)
  vim.wo[globals.sidebar_win].winfixwidth = true
  vim.api.nvim_win_set_width(globals.sidebar_win, SIDEBAR_WIDTH)

  -- The split takes its columns from the rightmost window; spread the loss
  -- over all splits so their ratios stay as the user arranged them.
  if before then
    layout.apply(before, nil, is_sidebar_win)
    vim.api.nvim_win_set_width(globals.sidebar_win, SIDEBAR_WIDTH)
  end
  layout_before_open = before
  layout_after_open = layout.capture(is_sidebar_win)
end

function M.get_buffer_list()
  return buffer_list
end

function M.get_buffer_at_cursor()
  return buffer_list[vim.api.nvim_win_get_cursor(globals.sidebar_win)[1]]
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

  preview.attach(M)

  M._is_opening = false
  status_watch.refresh_git()
end

function M.is_opened()
  return globals.sidebar_win and vim.api.nvim_win_is_valid(globals.sidebar_win)
end

function M.close()
  if M.is_opened() then
    preview.close()

    local current = layout.capture(is_sidebar_win)
    local source = current
    if layout_before_open and vim.deep_equal(current, layout_after_open) then
      source = layout_before_open
    end
    layout_before_open, layout_after_open = nil, nil

    layout.without_equalalways(function()
      vim.api.nvim_win_close(globals.sidebar_win, true)
    end)
    globals.sidebar_win = nil
    globals.sidebar_buf = nil

    -- Closing hands all freed columns to one neighbour; give them back proportionally
    if source then
      layout.apply(source)
    end
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

  buffer_list = buffers.get_list()
  render.draw(buffer_list, vim.api.nvim_get_current_buf())

  if M.is_opened() then
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

status_watch.setup(M)

vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function(ev)
    -- Unlisted buffers (preview scratch, plugin UIs) never appear in the sidebar
    if vim.bo[ev.buf].buflisted and ev.match ~= "oil" and ev.match ~= "oilBrowser" then
      M.schedule_update(OIL_SETTLE_MS)
    end
  end
})

return M
