Config = require("pile.config")
local buffers = require("pile.buffers")
local sidebar = require("pile.windows.sidebar")

local M = {}

---@param opts Config
function M.setup(opts)
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
