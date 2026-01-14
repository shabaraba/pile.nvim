-- setupで受け取るconfigはここ
local M = {
  debug = {
    enabled = false, -- デフォルトではデバッグログを無効化
    level = "info",  -- デバッグレベル: "error", "warn", "info", "debug", "trace"
  }
}

M.setup = function(opts)
  opts = opts or {}

  -- 設定項目がnilの場合のデフォルト値を設定する関数
  local function set_default(path, default_value)
    local table_path = opts
    local levels = {}
    for part in string.gmatch(path, "[^.]+") do
      table.insert(levels, part)
    end

    for i = 1, #levels - 1 do
      local key = levels[i]
      if table_path[key] == nil then
        table_path[key] = {}
      end
      table_path = table_path[key]
    end

    local final_key = levels[#levels]
    if table_path[final_key] == nil then
      table_path[final_key] = default_value
    end

    return table_path[final_key]
  end

  -- デバッグ設定
  if opts and opts.debug ~= nil then
    M.debug.enabled = opts.debug.enabled ~= nil and opts.debug.enabled or M.debug.enabled
    M.debug.level = opts.debug.level ~= nil and opts.debug.level or M.debug.level
  end

  -- バッファハイライト設定
  M.buffer = {
    highlight = {
      current = {
        bg = "#3E4452",
        fg = "Red",
      },
    },
  }

  -- ウィンドウインジケーター設定
  M.window_indicator = {
    enabled = set_default("window_indicator.enabled", true),
    colors = set_default("window_indicator.colors", {
      "#E06C75", -- Red
      "#98C379", -- Green
      "#E5C07B", -- Yellow
      "#61AFEF", -- Blue
      "#C678DD", -- Magenta
      "#56B6C2", -- Cyan
      "#D19A66", -- Orange
      "#ABB2BF", -- Light Gray
      "#E06C75", -- Red (repeat)
      "#98C379", -- Green (repeat)
    }),
  }

  -- 履歴管理設定
  M.history = {
    enabled = set_default("history.enabled", true),
    auto_cleanup_days = set_default("history.auto_cleanup_days", 30),
  }

  -- ソート設定
  M.sort = {
    method = set_default("sort.method", "buffer_number"), -- "buffer_number", "mru", "frequency"
  }
end

return M
