local config = require('pile.config')

local M = {}

local function build_filter_func(windows)
  local allowed = {}
  for _, win in ipairs(windows) do
    allowed[win] = true
  end

  return function(window_ids)
    return vim.tbl_filter(function(win)
      return allowed[win] == true
    end, window_ids)
  end
end

function M.select_window(windows)
  local ok, window_picker = pcall(require, 'window-picker')
  if not ok then
    vim.notify(
      "pile.nvim requires s1n7ax/nvim-window-picker to choose a window.",
      vim.log.levels.ERROR
    )
    return nil
  end

  local opts = vim.tbl_deep_extend('force', config.window_picker or {}, {
    filter_func = build_filter_func(windows),
  })

  return window_picker.pick_window(opts)
end

return M
