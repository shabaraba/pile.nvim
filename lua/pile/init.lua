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

  -- ハイライトグループを定義（新しいAPIを使用）
  vim.api.nvim_set_hl(0, "SidebarCurrentBuffer", {
    bg = Config.buffer.highlight.current.bg,
    fg = Config.buffer.highlight.current.fg,
  })
  vim.api.nvim_set_hl(0, "SelectedWindow", {
    bg = "Red",
    fg = "White",
  })

  -- ウィンドウの色を自動更新するためのautocmd
  local window_colors = require('pile.window_colors')

  -- ウィンドウ作成・分割時
  vim.api.nvim_create_autocmd({"WinNew", "WinEnter"}, {
    pattern = "*",
    callback = function()
      -- サイドバーを更新（色の割り当ても含む）
      sidebar.update()
    end
  })

  -- バッファ切り替え時
  vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
    pattern = "*",
    callback = function()
      -- サイドバーを更新
      sidebar.update()
    end
  })

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
