-- ウィンドウごとの色割り当てを管理するモジュール
local M = {}

-- ウィンドウIDと色のマッピング
local window_color_map = {}
-- 次に割り当てる色のインデックス
local next_color_index = 1

-- ウィンドウIDに色を割り当てる（既に割り当てられている場合はその色を返す）
function M.assign_color(window_id, colors)
  if not window_id then
    return nil
  end

  -- 既に色が割り当てられている場合は、その色を返す
  if window_color_map[window_id] then
    return window_color_map[window_id]
  end

  -- 新しいウィンドウに色を割り当てる
  local color_index = ((next_color_index - 1) % #colors) + 1
  local color = colors[color_index]
  window_color_map[window_id] = color
  next_color_index = next_color_index + 1

  -- ハイライトグループを動的に作成
  local hl_group = string.format("PileWindowIndicator_%d", window_id)
  vim.api.nvim_set_hl(0, hl_group, {
    fg = color,
    bold = true,
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

return M
