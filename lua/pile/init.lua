local config = require("pile.config")
local buffers = require("pile.buffers")
local sidebar = require("pile.windows.sidebar")
local log = require("pile.log")
local history = require("pile.features.history")

local M = {}

local function check_dependencies()
  log.trace("Checking dependencies...")
  local has_nui = pcall(require, "nui.popup")
  if not has_nui then
    log.error("Required dependency nui.nvim not found. Please install it with your plugin manager.")
    vim.notify(
      "pile.nvim requires nui.nvim to be installed. Please add it to your plugin manager.",
      vim.log.levels.ERROR
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
end

local function setup_autocmds()
  vim.api.nvim_create_autocmd({"WinNew", "WinEnter"}, {
    pattern = "*",
    callback = function()
      sidebar.update()
    end
  })

  vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
    pattern = "*",
    callback = function()
      if config.history and config.history.enabled then
        local bufnr = vim.api.nvim_get_current_buf()
        history.record(bufnr)
      end
      sidebar.update()
    end
  })
end

local function setup_commands()
  vim.api.nvim_create_user_command("PileToggle", M.toggle_sidebar, { desc = "toggle pile window" })
  vim.api.nvim_create_user_command("PileGoToNextBuffer", M.switch_to_next_buffer, { desc = "go to next buffer" })
  vim.api.nvim_create_user_command("PileGoToPrevBuffer", M.switch_to_prev_buffer, { desc = "go to prev buffer" })
  vim.api.nvim_create_user_command("PileSetSortMode", M.set_sort_mode, {
    nargs = 1,
    complete = function() return {"buffer_number", "mru", "frequency", "score"} end,
    desc = "set buffer sort mode"
  })
  vim.api.nvim_create_user_command("PileHistoryStats", M.show_history_stats, { desc = "show history statistics" })
  vim.api.nvim_create_user_command("PileHistoryClear", M.clear_history, { desc = "clear all history" })
end

function M.setup(opts)
  if not check_dependencies() then
    return
  end

  config.setup(opts)
  setup_highlights()
  setup_autocmds()
  setup_commands()
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

function M.set_sort_mode(opts)
  local sort = require('pile.features.sort')
  local mode = opts.args
  if sort.set_mode(mode) then
    config.sort.method = mode
    sidebar.update()
    print("Sort mode changed to: " .. mode)
  else
    print("Invalid sort mode: " .. mode)
  end
end

function M.show_history_stats()
  local stats = history.stats()
  print("=== Pile History Statistics ===")
  print(string.format("Total entries: %d", stats.total_entries))
  print(string.format("Total accesses: %d", stats.total_accesses))
  if stats.oldest_access then
    print(string.format("Oldest access: %s", os.date("%Y-%m-%d %H:%M:%S", stats.oldest_access)))
  end
  if stats.newest_access then
    print(string.format("Newest access: %s", os.date("%Y-%m-%d %H:%M:%S", stats.newest_access)))
  end
end

function M.clear_history()
  if history.clear() then
    print("History cleared successfully")
    sidebar.update()
  else
    print("Failed to clear history")
  end
end

return M
