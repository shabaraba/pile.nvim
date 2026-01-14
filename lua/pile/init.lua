local config = require("pile.config")
local buffers = require("pile.buffers")
local sidebar = require("pile.windows.sidebar")
local log = require("pile.log")

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
      sidebar.update()
    end
  })
end

local function setup_commands()
  vim.api.nvim_create_user_command("PileToggle", M.toggle_sidebar, { desc = "toggle pile window" })
  vim.api.nvim_create_user_command("PileGoToNextBuffer", M.switch_to_next_buffer, { desc = "go to next buffer" })
  vim.api.nvim_create_user_command("PileGoToPrevBuffer", M.switch_to_prev_buffer, { desc = "go to prev buffer" })
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

return M
