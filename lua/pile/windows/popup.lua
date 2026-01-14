local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local popup_list = {}

local M = {}

function M.show_popup_on_win(win)
  local pos = vim.api.nvim_win_get_position(win)

  local popup = Popup({
    enter = false,
    focusable = false,
    border = { style = "rounded" },
    position = { row = pos[1], col = pos[2] },
    size = { width = 10, height = 1 },
    win_options = {
      winblend = 10,
      winhighlight = "Normal:Normal",
    },
  })
  popup:mount()
  popup:on(event.BufNew, function()
    if vim.api.nvim_get_current_buf() ~= popup.bufnr then
      popup:unmount()
    end
  end)
  return popup
end

local function label_windows(windows)
  for _, win in ipairs(windows) do
    local label = string.format("[%d]", vim.api.nvim_win_get_number(win))
    local popup = M.show_popup_on_win(win)
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, { label })
    table.insert(popup_list, popup)
  end
end

function M.select_window(windows, callback)
  require("dressing")
  label_windows(windows)
  vim.ui.select(windows, {
    prompt = "Select window to open buffer:",
    format_item = function(win)
      local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
      local bufname_short = vim.fn.fnamemodify(bufname, ":t")
      return string.format("Window %d [%s]", vim.api.nvim_win_get_number(win), bufname_short)
    end
  }, callback)
end

function M.unmount()
  for _, popup in ipairs(popup_list) do
    popup:unmount()
  end
  popup_list = {}
end

return M
