local M = {}

local window_color_map = {}
local next_color_index = 1

local function create_highlight_group(name, fg, opts)
  opts = opts or {}
  vim.api.nvim_set_hl(0, name, {
    fg = fg,
    bg = opts.bg or "NONE",
    bold = opts.bold or false,
  })
end

function M.assign_color(window_id, colors)
  if not window_id then
    return nil
  end

  if not colors or #colors == 0 then
    return nil
  end

  if window_color_map[window_id] then
    return window_color_map[window_id]
  end

  local color_index = ((next_color_index - 1) % #colors) + 1
  local color = colors[color_index]
  window_color_map[window_id] = color
  next_color_index = next_color_index + 1

  create_highlight_group(
    string.format("PileWindowIndicator_%d", window_id),
    color,
    { bold = true }
  )
  create_highlight_group(
    string.format("PileWindowBorder_%d", window_id),
    color
  )

  return color
end

function M.get_color(window_id)
  if not window_id then
    return nil
  end
  return window_color_map[window_id]
end

function M.cleanup()
  local valid_windows = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    valid_windows[win] = true
  end

  for win_id in pairs(window_color_map) do
    if not valid_windows[win_id] then
      window_color_map[win_id] = nil
    end
  end
end

function M.reset()
  window_color_map = {}
  next_color_index = 1
end

function M.apply_to_window(window_id)
  if not window_id or not vim.api.nvim_win_is_valid(window_id) then
    return
  end

  local color = window_color_map[window_id]
  if not color then
    return
  end

  local hl_group = string.format("PileCursorLineNr_%d", window_id)
  create_highlight_group(hl_group, color, { bold = true })

  vim.wo[window_id].winhighlight = string.format('CursorLineNr:%s', hl_group)
end

function M.apply_all_windows()
  for window_id in pairs(window_color_map) do
    if vim.api.nvim_win_is_valid(window_id) then
      M.apply_to_window(window_id)
    end
  end
end

function M.show_mappings()
  print("=== Window Color Mappings ===")
  local windows = vim.tbl_keys(window_color_map)
  table.sort(windows)
  for i, win_id in ipairs(windows) do
    local color = window_color_map[win_id]
    local valid = vim.api.nvim_win_is_valid(win_id)
    print(string.format("[%d] Window %d: %s (valid: %s)", i, win_id, color, tostring(valid)))
  end
end

function M.get_all_mappings()
  return window_color_map
end

return M
