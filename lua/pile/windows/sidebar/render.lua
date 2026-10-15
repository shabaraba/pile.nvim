local globals = require 'pile.globals'
local window_colors = require 'pile.window_colors'
local config = require 'pile.config'
local icons = require 'pile.icons'
local marks = require 'pile.windows.sidebar.marks'

local ns_id = vim.api.nvim_create_namespace('pile_line_prefixes')

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

--- @param window_ids number[] Windows showing the buffer; buffers.get_list() already leaves out the sidebar
local function build_indicator_virt_text(window_ids)
  local virt_text = {}

  for _, window_id in ipairs(window_ids) do
    local color = window_colors.assign_color(window_id, config.window_indicator.colors)
    if color then
      window_colors.apply_to_window(window_id)
      local hl_group = string.format("PileWindowIndicator_%d", window_id)
      table.insert(virt_text, {"\226\150\136", hl_group})
    end
  end

  return virt_text
end

local function window_indicators_enabled()
  return config.window_indicator.enabled
end

local function build_prefix_virt_text(buffer)
  local virt_text = {}

  if window_indicators_enabled() then
    virt_text = build_indicator_virt_text(buffer.window_ids or {})
    if #virt_text > 0 then
      table.insert(virt_text, {" ", "Normal"})
    end
  end

  if config.icons.enabled then
    local icon, hl = icons.get(buffer.name)
    if icon then
      table.insert(virt_text, {icon, hl})
      table.insert(virt_text, {" ", "Normal"})
    end
  end

  return virt_text
end

local function apply_decorations(buffer_list)
  vim.api.nvim_buf_clear_namespace(globals.sidebar_buf, ns_id, 0, -1)

  if window_indicators_enabled() then
    window_colors.cleanup()
    if vim.tbl_isempty(window_colors.get_all_mappings()) then
      window_colors.reset()
    end
  end

  for i, buffer in ipairs(buffer_list) do
    local virt_text = build_prefix_virt_text(buffer)
    if #virt_text > 0 then
      vim.api.nvim_buf_set_extmark(globals.sidebar_buf, ns_id, i - 1, 0, {
        virt_text = virt_text,
        virt_text_pos = "inline",
        priority = 100,
      })
    end

    local status_marks = marks.build(buffer)
    if #status_marks > 0 then
      vim.api.nvim_buf_set_extmark(globals.sidebar_buf, ns_id, i - 1, 0, {
        virt_text = status_marks,
        virt_text_pos = "right_align",
        priority = 100,
      })
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
  apply_decorations(buffer_list)
end

return M
