--- Which tabs each buffer belongs to
--- A buffer joins the current tab when it is added or entered there and stays a
--- member whether or not a window shows it. Buffers that belong to no open tab
--- are "unassigned".
local M = {}

local members = {}

function M.add(tab, buf)
  members[tab] = members[tab] or {}
  members[tab][buf] = true
end

function M.has(tab, buf)
  return members[tab] ~= nil and members[tab][buf] == true
end

local function remove_buffer(buf)
  for _, bufs in pairs(members) do
    bufs[buf] = nil
  end
end

local function prune_tabs()
  for tab in pairs(members) do
    if not vim.api.nvim_tabpage_is_valid(tab) then
      members[tab] = nil
    end
  end
end

--- Record what is already open: each tab's displayed buffers, and listed
--- buffers shown nowhere in the current tab (they were added before pile started)
local function seed()
  local displayed = {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      local buf = vim.api.nvim_win_get_buf(win)
      M.add(tab, buf)
      displayed[buf] = true
    end
  end

  local current = vim.api.nvim_get_current_tabpage()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if not displayed[buf] and vim.bo[buf].buflisted then
      M.add(current, buf)
    end
  end
end

--- @param group number Augroup the autocmds belong to
function M.setup(group)
  seed()

  vim.api.nvim_create_autocmd({"BufAdd", "BufEnter", "BufWinEnter"}, {
    group = group,
    callback = function(ev)
      M.add(vim.api.nvim_get_current_tabpage(), ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({"BufDelete", "BufWipeout"}, {
    group = group,
    callback = function(ev)
      remove_buffer(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd("TabClosed", {
    group = group,
    callback = prune_tabs,
  })
end

return M
