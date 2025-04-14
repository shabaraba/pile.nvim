Config = require("pile.config")
local buffers = require("pile.buffers")
local sidebar = require("pile.windows.sidebar")
local log = require("pile.log")

local M = {}

-- nui.nvimの依存関係をチェック
local function check_dependencies()
  log.trace("Checking dependencies...")
  local has_nui, nui = pcall(require, "nui.popup")
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

---@param opts Config
function M.setup(opts)
  -- 依存関係のチェック
  if not check_dependencies() then
    return
  end
  
  Config.setup(opts)

  -- ハイライトグループを定義
  vim.cmd("highlight SidebarCurrentBuffer guibg=Config.buffer.highlight.current.bg guifg=Red")
  vim.cmd("highlight SelectedWindow guibg=Red guifg=White")

  vim.api.nvim_create_user_command("PileToggle", M.toggle_sidebar, { desc = "toggle pile window" })
  vim.api.nvim_create_user_command("PileGoToNextBuffer", M.switch_to_next_buffer, { desc = "go to next buffer" })
  vim.api.nvim_create_user_command("PileGoToPrevBuffer", M.switch_to_prev_buffer, { desc = "go to prev buffer" })
end

function M.toggle_sidebar()
  sidebar.toggle()
end

-- 現在のバッファを一つ下のバッファに切り替える関数
function M.switch_to_next_buffer()
  buffers.next()
end

-- 現在のバッファを一つ上のバッファに切り替える関数
function M.switch_to_prev_buffer()
  buffers.prev()
end

return M
