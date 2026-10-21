--- Keep the sidebar in every tab while it is open
local globals = require 'pile.globals'
local wins = require 'pile.windows.sidebar.wins'

local M = {}

local function show_in_current_tab(sidebar)
  if not sidebar.is_opened() or sidebar._suspended or wins.get() then
    return
  end
  if not (globals.sidebar_buf and vim.api.nvim_buf_is_valid(globals.sidebar_buf)) then
    return
  end
  local win = vim.api.nvim_get_current_win()
  wins.open(globals.sidebar_buf)
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
end

--- @param sidebar table Sidebar module
--- @param group number Augroup
function M.setup(sidebar, group)
  -- Deferred so that `:tabnew file` has put its buffer in place first
  vim.api.nvim_create_autocmd("TabEnter", {
    group = group,
    callback = vim.schedule_wrap(function()
      show_in_current_tab(sidebar)
      sidebar.schedule_update()
    end),
  })

  vim.api.nvim_create_autocmd("TabClosed", {
    group = group,
    callback = function()
      wins.prune()
      sidebar.schedule_update()
    end,
  })

  -- Closing the sidebar window by hand (:q, :only) closes it in every tab;
  -- closing a whole tab only drops that tab's window
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      local win = tonumber(ev.match)
      if not (sidebar.is_opened() and wins.is_sidebar(win)) then
        return
      end
      local tab = vim.api.nvim_win_get_tabpage(win)
      vim.schedule(function()
        wins.prune()
        if sidebar.is_opened() and vim.api.nvim_tabpage_is_valid(tab) and not wins.get(tab) then
          sidebar.close()
        end
      end)
    end,
  })
end

return M
