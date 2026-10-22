local globals = require 'pile.globals'
local window_colors = require 'pile.window_colors'
local config = require 'pile.config'
local icons = require 'pile.icons'
local marks = require 'pile.windows.sidebar.marks'

local ns_id = vim.api.nvim_create_namespace('pile_line_decorations')

local M = {}

--- Text of a buffer line; header lines show their group label
function M.buffer_text(buffer)
  return buffer.alias or buffer.filename
end

local function rows_to_lines(rows)
  return vim.tbl_map(function(row)
    return row.buffer and M.buffer_text(row.buffer) or row.group.label
  end, rows)
end

local function highlight_lines(rows, target_buffer)
  local current_tab = vim.api.nvim_get_current_tabpage()
  for i, row in ipairs(rows) do
    local buffer = row.buffer
    if not buffer then
      vim.api.nvim_buf_add_highlight(globals.sidebar_buf, -1, "PileTabHeader", i - 1, 0, -1)
    elseif buffer.alias then
      vim.api.nvim_buf_add_highlight(globals.sidebar_buf, -1, "PileAlias", i - 1, 0, -1)
    end
    if buffer and buffer.buf == target_buffer and row.group.tab == current_tab then
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

local function set_virt_text(line, virt_text, pos)
  if #virt_text > 0 then
    vim.api.nvim_buf_set_extmark(globals.sidebar_buf, ns_id, line, 0, {
      virt_text = virt_text,
      virt_text_pos = pos,
      priority = 100,
    })
  end
end

local function apply_decorations(rows)
  vim.api.nvim_buf_clear_namespace(globals.sidebar_buf, ns_id, 0, -1)

  if window_indicators_enabled() then
    window_colors.cleanup()
    if vim.tbl_isempty(window_colors.get_all_mappings()) then
      window_colors.reset()
    end
  end

  for i, row in ipairs(rows) do
    if row.buffer then
      set_virt_text(i - 1, build_prefix_virt_text(row.buffer), "inline")
      set_virt_text(i - 1, marks.build(row.buffer), "right_align")
    end
  end
end

--- Draw group headers and buffers into the sidebar buffer
--- @param rows table[] From groups.rows()
--- @param current_buf number Buffer to highlight as current in the current tab's group
function M.draw(rows, current_buf)
  vim.api.nvim_buf_set_lines(globals.sidebar_buf, 0, -1, false, rows_to_lines(rows))

  highlight_lines(rows, current_buf)
  apply_decorations(rows)
end

return M
