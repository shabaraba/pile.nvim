-- setupで受け取るconfigはここ
local M = {
  debug = {
    enabled = false, -- デフォルトではデバッグログを無効化
    level = "info",  -- デバッグレベル: "error", "warn", "info", "debug", "trace"
  },
  -- セッション管理の設定
  session = {
    enabled = true,                -- セッション機能の有効/無効
    auto_save = true,              -- 自動保存するか
    auto_load = true,              -- 起動時に自動で最後のセッションを読み込むか
    save_interval = 300,           -- 自動保存の間隔（秒）
    db_path = nil,                 -- SQLiteのDBパス（nilの場合はデフォルト場所）
    save_on_exit = true,           -- 終了時に自動保存するか
    clear_buffers_on_load = false  -- セッション読み込み時に既存バッファをクリアするか
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

  -- セッション設定
  if opts and opts.session ~= nil then
    -- 各設定項目をユーザー設定またはデフォルト値で設定
    M.session.enabled = opts.session.enabled ~= nil and opts.session.enabled or M.session.enabled
    M.session.auto_save = opts.session.auto_save ~= nil and opts.session.auto_save or M.session.auto_save
    M.session.auto_load = opts.session.auto_load ~= nil and opts.session.auto_load or M.session.auto_load
    M.session.save_interval = opts.session.save_interval ~= nil and opts.session.save_interval or M.session.save_interval
    M.session.db_path = opts.session.db_path ~= nil and opts.session.db_path or M.session.db_path
    M.session.save_on_exit = opts.session.save_on_exit ~= nil and opts.session.save_on_exit or M.session.save_on_exit
    M.session.clear_buffers_on_load = opts.session.clear_buffers_on_load ~= nil and opts.session.clear_buffers_on_load or M.session.clear_buffers_on_load
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
