-- ウィンドウごとの色割り当てを管理するモジュール
local M = {}

-- ウィンドウIDと色のマッピング
local window_color_map = {}
-- 次に使用する色のインデックス（使用済みの色数を追跡）
local next_color_index = 1

-- ウィンドウIDに色を割り当てる（既に割り当てられている場合はその色を返す）
function M.assign_color(window_id, colors)
  if not window_id then
    return nil
  end

  -- 既に色が割り当てられている場合は、その色を返す（絶対に変更しない）
  if window_color_map[window_id] then
    return window_color_map[window_id]
  end

  -- 新しいウィンドウに色を割り当てる
  local color_index = ((next_color_index - 1) % #colors) + 1
  local color = colors[color_index]
  window_color_map[window_id] = color
  next_color_index = next_color_index + 1

  -- インジケーター用のハイライトグループを動的に作成
  local hl_group = string.format("PileWindowIndicator_%d", window_id)
  vim.api.nvim_set_hl(0, hl_group, {
    fg = color,
    bold = true,
  })

  -- ウィンドウ枠用のハイライトグループを作成
  local border_hl_group = string.format("PileWindowBorder_%d", window_id)
  vim.api.nvim_set_hl(0, border_hl_group, {
    fg = color,
    bg = "NONE",
  })

  return color
end

-- ウィンドウIDから色を取得する
function M.get_color(window_id)
  if not window_id then
    return nil
  end
  return window_color_map[window_id]
end

-- 無効なウィンドウの色割り当てをクリアする
function M.cleanup()
  local valid_windows = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      valid_windows[win] = true
    end
  end

  -- 無効なウィンドウのマッピングを削除
  for win_id, _ in pairs(window_color_map) do
    if not valid_windows[win_id] then
      window_color_map[win_id] = nil
    end
  end
end

-- すべての色割り当てをリセットする
function M.reset()
  window_color_map = {}
  next_color_index = 1
end

-- ウィンドウに色を適用する
function M.apply_to_window(window_id)
  if not window_id or not vim.api.nvim_win_is_valid(window_id) then
    return
  end

  local color = window_color_map[window_id]
  if not color then
    return
  end

  -- カーソル行番号用のハイライトグループを作成
  local cursorlinenr_hl_group = string.format("PileCursorLineNr_%d", window_id)
  vim.api.nvim_set_hl(0, cursorlinenr_hl_group, {
    fg = color,
    bold = true,
  })

  -- winhighlightでカーソル行の行番号の色を変更
  vim.api.nvim_win_set_option(window_id, 'winhighlight',
    string.format('CursorLineNr:%s', cursorlinenr_hl_group))
end

-- すべての色付きウィンドウに色を再適用する
function M.apply_all_windows()
  for window_id, _ in pairs(window_color_map) do
    if vim.api.nvim_win_is_valid(window_id) then
      M.apply_to_window(window_id)
    end
  end
end

-- デバッグ用: 現在の色マッピング状況を表示
function M.show_mappings()
  print("=== Window Color Mappings ===")
  -- ウィンドウIDでソートして表示
  local windows = vim.tbl_keys(window_color_map)
  table.sort(windows)
  for i, win_id in ipairs(windows) do
    local color = window_color_map[win_id]
    local valid = vim.api.nvim_win_is_valid(win_id)
    print(string.format("[%d] Window %d: %s (valid: %s)", i, win_id, color, tostring(valid)))
  end
end

-- 全マッピングを取得（内部使用）
function M.get_all_mappings()
  return window_color_map
end

return M
