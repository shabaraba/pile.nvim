-- setupで受け取るconfigはここ
local M = {
  debug = {
    enabled = false, -- デフォルトではデバッグログを無効化
    level = "info",  -- デバッグレベル: "error", "warn", "info", "debug", "trace"
  },
  display = {
    show_terminal_buffers = false, -- ターミナルバッファを表示するかどうか
  }
}

M.setup = function(opts)
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

  -- 表示設定
  if opts and opts.display ~= nil then
    M.display.show_terminal_buffers = opts.display.show_terminal_buffers ~= nil and opts.display.show_terminal_buffers or M.display.show_terminal_buffers
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
  
  -- その他の設定があれば追加
end

return M
