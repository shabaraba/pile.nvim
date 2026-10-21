--- Which tabs each buffer belongs to
--- A buffer joins the current tab when it is added or entered there and stays a
--- member whether or not a window shows it. Buffers that belong to no open tab
--- are "unassigned". A tab may also keep its own order of its members.
local M = {}

local members = {}
local orders = {}
local quiet = false

function M.add(tab, buf)
  members[tab] = members[tab] or {}
  members[tab][buf] = true
end

function M.remove(tab, buf)
  if members[tab] then
    members[tab][buf] = nil
  end
  if orders[tab] then
    orders[tab][buf] = nil
  end
end

function M.has(tab, buf)
  return members[tab] ~= nil and members[tab][buf] == true
end

--- @return number[] Open tabs `buf` belongs to
function M.tabs_of(buf)
  local tabs = {}
  for tab, bufs in pairs(members) do
    if bufs[buf] and vim.api.nvim_tabpage_is_valid(tab) then
      table.insert(tabs, tab)
    end
  end
  return tabs
end

--- Record the order of a tab's members; members left out rank after them
--- @param bufs number[]
function M.set_order(tab, bufs)
  orders[tab] = {}
  for rank, buf in ipairs(bufs) do
    if M.has(tab, buf) then
      orders[tab][buf] = rank
    end
  end
end

--- Make `bufs`, in this order, the only members of `tab`
--- @param bufs number[]
function M.reset(tab, bufs)
  members[tab] = {}
  for _, buf in ipairs(bufs) do
    M.add(tab, buf)
  end
  M.set_order(tab, bufs)
end

--- @return table<number, number>|nil Rank of each ordered member of `tab`
function M.order_of(tab)
  return orders[tab]
end

--- Drop every tab's own order so that groups follow the buffer list again
function M.clear_orders()
  orders = {}
end

--- Run `fn` without recording the buffers it adds or enters
function M.quietly(fn)
  local was_quiet = quiet
  quiet = true
  local ok, err = pcall(fn)
  quiet = was_quiet
  if not ok then
    error(err, 0)
  end
end

local function remove_buffer(buf)
  for tab in pairs(members) do
    M.remove(tab, buf)
  end
end

local function prune_tabs()
  for tab in pairs(members) do
    if not vim.api.nvim_tabpage_is_valid(tab) then
      members[tab] = nil
      orders[tab] = nil
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
      if not quiet then
        M.add(vim.api.nvim_get_current_tabpage(), ev.buf)
      end
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
