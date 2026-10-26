local globals = require 'pile.globals'
local window_colors = require 'pile.window_colors'
local config = require 'pile.config'
local icons = require 'pile.icons'
local marks = require 'pile.windows.sidebar.marks'
local separators = require 'pile.windows.sidebar.separators'

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

--- Give every window its color (tinting its CursorLineNr)
--- @param window_ids number[] Windows showing the buffer; buffers.get_list() already leaves out the sidebar
--- @return number[] Windows that got a color
local function colored_windows(window_ids)
  return vim.tbl_filter(function(window_id)
    if window_colors.assign_color(window_id, config.window_indicator.colors) then
      window_colors.apply_to_window(window_id)
      return true
    end
    return false
  end, window_ids)
end

--- The line shows one color; the current window's wins
local function line_window(window_ids)
  local current = vim.api.nvim_get_current_win()
  return vim.tbl_contains(window_ids, current) and current or window_ids[1]
end

local function window_indicators_enabled()
  return config.window_indicator.enabled
end

--- @return "block"|"line"|nil nil when indicators are disabled
local function indicator_style()
  return window_indicators_enabled() and config.window_indicator.style or nil
end

--- @param position "left"|"right"
local function blocks_at(position)
  return indicator_style() == "block" and config.window_indicator.position == position
end

local function build_blocks(window_ids)
  return vim.tbl_map(function(window_id)
    return {"\226\150\136", string.format("PileWindowIndicator_%d", window_id)}
  end, window_ids)
end

local function set_line_indicator(line, window_id)
  if window_id then
    vim.api.nvim_buf_set_extmark(globals.sidebar_buf, ns_id, line, 0, {
      number_hl_group = string.format("PileWindowIndicator_%d", window_id),
      line_hl_group = string.format("PileWindowUnderline_%d", window_id),
      priority = 100,
    })
  end
end

--- @param position "left"|"right"
--- @return table|nil virt_text chunk when the icon is shown on that side
local function icon_chunk(buffer, position)
  if not config.icons.enabled or config.icons.position ~= position then
    return nil
  end
  local icon, hl = icons.get(buffer.name)
  return icon and {icon, hl} or nil
end

local function build_prefix_virt_text(buffer, window_ids)
  local virt_text = {}

  if blocks_at("left") and #window_ids > 0 then
    virt_text = build_blocks(window_ids)
    table.insert(virt_text, {" ", "Normal"})
  end

  local icon = icon_chunk(buffer, "left")
  if icon then
    table.insert(virt_text, icon)
    table.insert(virt_text, {" ", "Normal"})
  end

  return virt_text
end

--- Space-separated right-aligned parts: status marks, right-side blocks, then a right-side icon
local function build_suffix_virt_text(buffer, window_ids)
  local parts = { marks.build(buffer) }
  if blocks_at("right") then
    table.insert(parts, build_blocks(window_ids))
  end
  table.insert(parts, { icon_chunk(buffer, "right") })

  local virt_text = {}
  for _, part in ipairs(parts) do
    if #part > 0 then
      if #virt_text > 0 then
        table.insert(virt_text, {" ", "Normal"})
      end
      vim.list_extend(virt_text, part)
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
      local window_ids = window_indicators_enabled() and colored_windows(row.buffer.window_ids or {}) or {}
      if indicator_style() == "line" then
        set_line_indicator(i - 1, line_window(window_ids))
      end
      set_virt_text(i - 1, build_prefix_virt_text(row.buffer, window_ids), "inline")
      set_virt_text(i - 1, build_suffix_virt_text(row.buffer, window_ids), "right_align")
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
  separators.draw(globals.sidebar_buf, vim.tbl_map(function(row) return not row.buffer end, rows))
end

return M
