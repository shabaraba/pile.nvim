--- Sidebar windows, one per tab
local layout = require 'pile.windows.layout'

local M = {}

local WIDTH = 35

-- tabpage -> { win, before, after }. before/after are the split layout around
-- the sidebar's opening, so closing can restore the exact sizes instead of
-- re-scaling (and accumulating rounding drift) when nothing changed.
local entries = {}

--- @param tab number|nil Tabpage; defaults to the current tab
--- @return number|nil
function M.get(tab)
  local entry = entries[tab or vim.api.nvim_get_current_tabpage()]
  if entry and vim.api.nvim_win_is_valid(entry.win) then
    return entry.win
  end
end

function M.is_sidebar(win)
  return vim.api.nvim_win_is_valid(win) and vim.w[win].pile_sidebar == true
end

--- @return table<number, number> tabpage -> window, valid windows only
function M.all()
  local result = {}
  for tab in pairs(entries) do
    result[tab] = M.get(tab)
  end
  return result
end

function M.prune()
  for tab in pairs(entries) do
    if not M.get(tab) then
      entries[tab] = nil
    end
  end
end

function M.fix_width()
  local win = M.get()
  if win then
    vim.api.nvim_win_set_width(win, WIDTH)
  end
end

--- Open a sidebar window showing `buf` on the far left of the current tab
--- @return number win
function M.open(buf)
  local before = layout.capture()

  layout.without_equalalways(function()
    vim.cmd('topleft ' .. WIDTH .. 'vsplit')
  end)
  local win = vim.api.nvim_get_current_win()
  vim.w[win].pile_sidebar = true

  vim.api.nvim_win_set_buf(win, buf)
  vim.wo[win].winfixwidth = true
  vim.api.nvim_win_set_width(win, WIDTH)

  -- The split takes its columns from the rightmost window; spread the loss
  -- over all splits so their ratios stay as the user arranged them.
  if before then
    layout.apply(before, nil, M.is_sidebar)
    vim.api.nvim_win_set_width(win, WIDTH)
  end
  entries[vim.api.nvim_get_current_tabpage()] = {
    win = win,
    before = before,
    after = layout.capture(M.is_sidebar),
  }
  return win
end

--- Close the sidebar window of `tab`, giving its columns back proportionally
function M.close(tab)
  local win = M.get(tab)
  local entry = entries[tab]
  entries[tab] = nil
  if not win then
    return
  end

  local source = layout.capture(M.is_sidebar, tab)
  if entry.before and vim.deep_equal(source, entry.after) then
    source = entry.before
  end

  layout.without_equalalways(function()
    vim.api.nvim_win_close(win, true)
  end)

  -- Closing hands all freed columns to one neighbour
  if source and vim.api.nvim_tabpage_is_valid(tab) then
    layout.apply(source, layout.capture(nil, tab))
  end
end

return M
