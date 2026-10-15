local globals = require 'pile.globals'
local window_colors = require 'pile.window_colors'
local config = require 'pile.config'

local ns_id = vim.api.nvim_create_namespace('pile_window_indicators')

local M = {}

local function buffer_list_to_lines(buffer_list)
  local lines = {}
  for _, buffer in ipairs(buffer_list) do
    table.insert(lines, buffer.filename)
  end
  return lines
end

local function highlight_current_buffer(buffer_list, target_buffer)
  for i, buffer in ipairs(buffer_list) do
    if buffer.buf == target_buffer then
      vim.api.nvim_buf_add_highlight(globals.sidebar_buf, -1, "SidebarCurrentBuffer", i - 1, 0, -1)
    end
  end
end

local function is_sidebar_window(window_id, win_buf)
  return window_id == globals.sidebar_win or win_buf == globals.sidebar_buf
end

local function build_indicator_virt_text(window_ids)
  local virt_text = {}

  for _, window_id in ipairs(window_ids) do
    local win_buf = vim.api.nvim_win_get_buf(window_id)
    if not is_sidebar_window(window_id, win_buf) then
      local color = window_colors.assign_color(window_id, config.window_indicator.colors)
      if color then
        window_colors.apply_to_window(window_id)
        local hl_group = string.format("PileWindowIndicator_%d", window_id)
        table.insert(virt_text, {"\226\150\136", hl_group})
      end
    end
  end

  return virt_text
end

local function apply_window_indicators(buffer_list)
  if not config.window_indicator or not config.window_indicator.enabled then
    return
  end

  vim.api.nvim_buf_clear_namespace(globals.sidebar_buf, ns_id, 0, -1)

  window_colors.cleanup()
  if vim.tbl_isempty(window_colors.get_all_mappings()) then
    window_colors.reset()
  end

  for i, buffer in ipairs(buffer_list) do
    if buffer.window_ids and #buffer.window_ids > 0 then
      local virt_text = build_indicator_virt_text(buffer.window_ids)

      if #virt_text > 0 then
        table.insert(virt_text, {" ", "Normal"})
        vim.api.nvim_buf_set_extmark(globals.sidebar_buf, ns_id, i - 1, 0, {
          virt_text = virt_text,
          virt_text_pos = "inline",
          priority = 100,
        })
      end
    end
  end
end

--- Draw the buffer list into the sidebar buffer
--- @param buffer_list table[]
--- @param current_buf number Buffer to highlight as current
function M.draw(buffer_list, current_buf)
  vim.bo[globals.sidebar_buf].modifiable = true
  vim.api.nvim_buf_set_lines(globals.sidebar_buf, 0, -1, false, buffer_list_to_lines(buffer_list))
  vim.bo[globals.sidebar_buf].modifiable = false

  highlight_current_buffer(buffer_list, current_buf)
  apply_window_indicators(buffer_list)
end

return M
