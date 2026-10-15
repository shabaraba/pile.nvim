local globals = require 'pile.globals'
local config = require 'pile.config'

local M = {}

local MAX_WIDTH = 100
local augroup = vim.api.nvim_create_augroup("PilePreview", { clear = true })

local state = {
  active = false,
  win = nil,
  scratch_buf = nil,
  shown_buf = nil,
}

local function float_config(buffer)
  local col = vim.api.nvim_win_get_width(globals.sidebar_win) + 1
  return {
    relative = 'editor',
    row = 0,
    col = col,
    width = math.min(MAX_WIDTH, vim.o.columns - col - 2),
    height = math.max(1, vim.o.lines - vim.o.cmdheight - 4),
    title = ' ' .. vim.fn.fnamemodify(buffer.name, ':~:.') .. ' ',
  }
end

--- Unloaded buffers are shown through a scratch copy so that previewing
--- does not trigger BufRead autocmds, LSP attach, etc. for them.
local function fill_scratch(buffer, height)
  if not (state.scratch_buf and vim.api.nvim_buf_is_valid(state.scratch_buf)) then
    state.scratch_buf = vim.api.nvim_create_buf(false, true)
  end
  local buf = state.scratch_buf
  local ok, lines = pcall(vim.fn.readfile, buffer.name, '', height)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, ok and lines or {})
  vim.bo[buf].filetype = vim.filetype.match({ filename = buffer.name, buf = buf }) or ''
  return buf
end

local function window_is_open()
  return state.win and vim.api.nvim_win_is_valid(state.win)
end

local function close_window()
  if window_is_open() then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.scratch_buf and vim.api.nvim_buf_is_valid(state.scratch_buf) then
    vim.api.nvim_buf_delete(state.scratch_buf, { force = true })
  end
  state.win = nil
  state.scratch_buf = nil
  state.shown_buf = nil
end

local function show(buffer)
  if not buffer or not globals.sidebar_win or not vim.api.nvim_win_is_valid(globals.sidebar_win) then
    close_window()
    return
  end
  if buffer.buf == state.shown_buf and window_is_open() then
    return
  end

  local win_config = float_config(buffer)
  local loaded = vim.api.nvim_buf_is_loaded(buffer.buf)
  local target = loaded and buffer.buf or fill_scratch(buffer, win_config.height)

  if window_is_open() then
    local eventignore = vim.o.eventignore
    vim.o.eventignore = 'all'
    vim.api.nvim_win_set_buf(state.win, target)
    vim.o.eventignore = eventignore
    vim.api.nvim_win_set_config(state.win, win_config)
  else
    -- noautocmd keeps WinNew/BufEnter from rebuilding the sidebar for the float
    state.win = vim.api.nvim_open_win(target, false, vim.tbl_extend('force', win_config, {
      border = config.preview.border,
      focusable = false,
      style = 'minimal',
      zindex = 45,
      noautocmd = true,
    }))
  end
  state.shown_buf = buffer.buf

  if loaded then
    local mark = vim.api.nvim_buf_get_mark(buffer.buf, '"')
    pcall(vim.api.nvim_win_set_cursor, state.win, { math.max(mark[1], 1), mark[2] })
  end
end

function M.close()
  state.active = false
  close_window()
end

--- @param buffer table|nil Buffer entry under the sidebar cursor
function M.toggle(buffer)
  if state.active then
    M.close()
  else
    state.active = true
    show(buffer)
  end
end

--- @param sidebar table Sidebar module providing get_buffer_at_cursor()
function M.attach(sidebar)
  vim.api.nvim_clear_autocmds({ group = augroup })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup,
    buffer = globals.sidebar_buf,
    callback = function()
      if state.active then
        show(sidebar.get_buffer_at_cursor())
      end
    end,
  })
  vim.api.nvim_create_autocmd({"WinLeave", "BufWipeout"}, {
    group = augroup,
    buffer = globals.sidebar_buf,
    callback = M.close,
  })

  if config.preview.auto_open then
    local function open()
      state.active = true
      show(sidebar.get_buffer_at_cursor())
    end
    vim.api.nvim_create_autocmd("BufEnter", {
      group = augroup,
      buffer = globals.sidebar_buf,
      callback = open,
    })
    open()
  end
end

return M
