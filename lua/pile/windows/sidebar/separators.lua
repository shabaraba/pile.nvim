--- Virtual lines above tab headers that mark where each tab group starts
local config = require 'pile.config'
local wins = require 'pile.windows.sidebar.wins'

local ns_id = vim.api.nvim_create_namespace('pile_tab_separators')

local M = {}

--- @param buf number
--- @param is_header boolean[] One entry per line, true on a tab header
function M.draw(buf, is_header)
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  if not config.tab_separator.enabled then
    return
  end

  local text = string.rep(config.tab_separator.char, wins.WIDTH)
  -- Line 1 is always a header; a virtual line above it stays hidden until scrolled to
  for i = 2, #is_header do
    if is_header[i] then
      vim.api.nvim_buf_set_extmark(buf, ns_id, i - 1, 0, {
        virt_lines = { { { text, "PileTabSeparator" } } },
        virt_lines_above = true,
      })
    end
  end
end

return M
