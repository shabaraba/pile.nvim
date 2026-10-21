--- Sidebar windows, one per tab
local globals = require 'pile.globals'
local layout = require 'pile.windows.layout'

local M = {}

local WIDTH = 35

-- Split layout of each tab around the sidebar's opening, so closing can
-- restore the exact sizes instead of re-scaling (and accumulating rounding
-- drift) when nothing changed.
local snapshots = {}

--- @param tab number|nil Tabpage; defaults to the current tab
--- @return number|nil
function M.get(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  local win = globals.sidebar_wins[tab]
  if win and vim.api.nvim_win_is_valid(win) then
    return win
  end
end

function M.is_sidebar(win)
  for _, sidebar_win in pairs(globals.sidebar_wins) do
    if sidebar_win == win then
      return true
    end
  end
  return false
end

--- @return table<number, number> tabpage -> window, valid windows only
function M.all()
  local result = {}
  for tab, win in pairs(globals.sidebar_wins) do
    if vim.api.nvim_win_is_valid(win) then
      result[tab] = win
    end
  end
  return result
end

function M.prune()
  globals.sidebar_wins = M.all()
  for tab in pairs(snapshots) do
    if not globals.sidebar_wins[tab] then
      snapshots[tab] = nil
    end
  end
end

function M.fix_widths()
  for _, win in pairs(M.all()) do
    vim.api.nvim_win_set_width(win, WIDTH)
  end
end

--- Open a sidebar window showing `buf` on the far left of the current tab
--- @return number win
function M.open(buf)
  local tab = vim.api.nvim_get_current_tabpage()
  local before = layout.capture()

  layout.without_equalalways(function()
    vim.cmd('topleft ' .. WIDTH .. 'vsplit')
  end)
  local win = vim.api.nvim_get_current_win()
  globals.sidebar_wins[tab] = win

  vim.api.nvim_win_set_buf(win, buf)
  vim.wo[win].winfixwidth = true
  vim.api.nvim_win_set_width(win, WIDTH)

  -- The split takes its columns from the rightmost window; spread the loss
  -- over all splits so their ratios stay as the user arranged them.
  if before then
    layout.apply(before, nil, M.is_sidebar)
    vim.api.nvim_win_set_width(win, WIDTH)
  end
  snapshots[tab] = { before = before, after = layout.capture(M.is_sidebar) }
  return win
end

--- Close the sidebar window of `tab`, giving its columns back proportionally
function M.close(tab)
  local win = M.get(tab)
  if not win then
    return
  end

  local snapshot = snapshots[tab] or {}
  local source
  vim.api.nvim_win_call(win, function()
    source = layout.capture(M.is_sidebar)
  end)
  if snapshot.before and vim.deep_equal(source, snapshot.after) then
    source = snapshot.before
  end
  snapshots[tab] = nil
  globals.sidebar_wins[tab] = nil

  layout.without_equalalways(function()
    vim.api.nvim_win_close(win, true)
  end)

  -- Closing hands all freed columns to one neighbour
  if source and vim.api.nvim_tabpage_is_valid(tab) then
    vim.api.nvim_win_call(vim.api.nvim_tabpage_get_win(tab), function()
      layout.apply(source)
    end)
  end
end

return M
