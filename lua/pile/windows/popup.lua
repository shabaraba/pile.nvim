local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local window = require("pile.windows")

local popup_list = {}

local M = {}

function M.show_popup_on_win(win)
  local width = vim.api.nvim_win_get_width(win)
  local height = vim.api.nvim_win_get_height(win)

  local pos = vim.api.nvim_win_get_position(win)
  local row = pos[1]
  local col = pos[2]

  -- ポップアップのサイズを計算（ウィンドウの50%とする）
  local popup_width = 10
  local popup_height = 10

  -- ポップアップの位置を計算（中央に配置）
  -- local row = math.floor((height - popup_height) / 2)
  -- local col = math.floor((width - popup_width) / 2)

  local popup = Popup({
    enter = false,
    focusable = false,
    border = {
      style = "rounded",
    },
    position = {
      row = row,
      col = col,
    },
    size = {
      width = 10, -- 文字単位
      height = 1, -- 行単位
    },
    win_options = {
      winblend = 10,
      winhighlight = "Normal:Normal",
    },
  })
  popup:mount()
  popup:on(event.BufNew, function()
    -- 現在のバッファがポップアップのバッファでない場合、ポップアップを閉じる
    if vim.api.nvim_get_current_buf() ~= popup.bufnr then
      popup:unmount()
    end
  end)
  return popup
end

-- 各ウィンドウに番号を表示する関数
local function label_windows(windows)
  for _, win in ipairs(windows) do
    local buf = vim.api.nvim_create_buf(false, true)
    local label = string.format("[%d]", vim.api.nvim_win_get_number(win))
    local popup = M.show_popup_on_win(win)
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, { label })
    table.insert(popup_list, popup)
  end
end

function M.select_window(windows, callback)
  require("dressing")
  label_windows(windows)
  -- 複数のウィンドウがある場合、ユーザーに選択させる
  vim.ui.select(windows, {
    prompt = "Select window to open buffer:",
    format_item = function(win)
      -- リッチな表示に、ウィンドウ番号や現在のバッファ名を追加
      local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
      local bufname_short = vim.fn.fnamemodify(bufname, ":t")
      return string.format("Window %d [%s]", vim.api.nvim_win_get_number(win), bufname_short)
    end
  }, callback
  )
end

function M.unmount()
  for _, popup in ipairs(popup_list) do
    popup:unmount()
  end
  popup_list = {}
end

return M
