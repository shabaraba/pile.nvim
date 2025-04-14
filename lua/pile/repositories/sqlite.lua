local log = require("pile.log")
local Config = require("pile.config")

local M = {}

-- SQLiteクライアントの初期化とテーブル作成
local function initialize()
  -- SQLite3の依存関係チェック
  local has_sqlite, sqlite = pcall(require, "sqlite")
  if not has_sqlite then
    log.error("SQLite3 module not found. Please install sqlite.lua.")
    vim.notify(
      "pile.nvim requires sqlite.lua for session functionality. Please install it with your plugin manager.",
      vim.log.levels.ERROR
    )
    return nil
  end

  -- データベースファイルのパスを設定
  local db_path = Config.session.db_path or vim.fn.stdpath("data") .. "/pile_sessions.db"
  log.debug("Using database path: " .. db_path)

  -- データベース接続
  local success, result = pcall(function() 
    return sqlite.new(db_path, {
      busy_timeout = 1000, -- 1秒のタイムアウト
    })
  end)

  if not success then
    -- エラーが発生した場合
    local err_msg = type(result) == "string" and result or "Unknown error"
    log.error("Failed to initialize SQLite database: " .. err_msg)
    return nil
  end

  -- 成功した場合、resultにはデータベース接続オブジェクトが入っている
  local db = result
  
  -- テーブル作成は try-catch で囲む
  local create_success, create_err = pcall(function()
    if type(db.exec) == "function" then
      -- 標準的なAPIの場合
      db:exec([[
        CREATE TABLE IF NOT EXISTS sessions (
          id INTEGER PRIMARY KEY,
          name TEXT UNIQUE,
          created_at TIMESTAMP,
          updated_at TIMESTAMP
        );
        
        CREATE TABLE IF NOT EXISTS session_buffers (
          id INTEGER PRIMARY KEY,
          session_id INTEGER,
          buffer_path TEXT,
          display_order INTEGER,
          cursor_position TEXT,
          is_active BOOLEAN,
          FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE
        );
      ]])
    elseif type(db.execute) == "function" then
      -- 別の一般的なAPI形式
      db:execute([[
        CREATE TABLE IF NOT EXISTS sessions (
          id INTEGER PRIMARY KEY,
          name TEXT UNIQUE,
          created_at TIMESTAMP,
          updated_at TIMESTAMP
        );
      ]])
      
      db:execute([[
        CREATE TABLE IF NOT EXISTS session_buffers (
          id INTEGER PRIMARY KEY,
          session_id INTEGER,
          buffer_path TEXT,
          display_order INTEGER,
          cursor_position TEXT,
          is_active BOOLEAN,
          FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE
        );
      ]])
    else
      error("SQLite API is not compatible. Neither exec nor execute method found.")
    end
  end)
  
  if not create_success then
    -- エラーを適切に文字列として扱う
    local err_msg = type(create_err) == "string" and create_err or "Unknown error"
    log.error("Failed to create tables: " .. err_msg)
    return nil
  end
  
  log.debug("SQLite database initialized successfully")
  return db
end

-- データベース接続の遅延初期化
local function get_db()
  if not M._db then
    M._db = initialize()
  end
  return M._db
end

-- セッションの保存
function M.save_session(name)
  if not Config.session.enabled then
    log.debug("Session functionality is disabled")
    return false
  end

  local db = get_db()
  if not db then
    return false
  end
  
  -- データベースのメソッドをチェック
  local with_transaction = type(db.with_transaction) == "function" and db.with_transaction
  if not with_transaction then
    log.error("SQLite API is missing required 'with_transaction' method")
    return false
  end

  local success, result = pcall(function()
    return db:with_transaction(function()
      -- 現在の時刻を取得
      local timestamp = os.date("%Y-%m-%d %H:%M:%S")
      
      -- 既存のセッションを確認
      local existing = db:select("sessions", { where = { name = name } })
      local session_id
      
      if #existing > 0 then
        -- 既存のセッションを更新
        session_id = existing[1].id
        db:update("sessions", {
          updated_at = timestamp
        }, {
          id = session_id
        })
        
        -- 既存のバッファ情報を削除
        db:delete("session_buffers", {
          session_id = session_id
        })
      else
        -- 新しいセッションを作成
        local result = db:insert("sessions", {
          name = name,
          created_at = timestamp,
          updated_at = timestamp
        })
        session_id = result.lastInsertRowid
      end
      
      -- バッファのリストを取得
      local buffers = require("pile.buffers").get_list()
      local current_buf = require("pile.buffers").get_current()
      
      -- 各バッファの情報を保存
      for i, buffer in ipairs(buffers) do
        -- カーソル位置を取得（現在のバッファのみ）
        local cursor_position = ""
        if buffer.buf == current_buf then
          local cursor = vim.api.nvim_win_get_cursor(0)
          cursor_position = string.format("%d,%d", cursor[1], cursor[2])
        end
        
        -- バッファ情報をデータベースに保存
        db:insert("session_buffers", {
          session_id = session_id,
          buffer_path = buffer.name,
          display_order = i,
          cursor_position = cursor_position,
          is_active = (buffer.buf == current_buf)
        })
      end
      
      return true
    end)
  end)
  
  if success and result then
    log.info("Session '" .. name .. "' saved successfully")
    return true
  else
    local err_msg = type(result) == "string" and result or "Unknown error"
    log.error("Failed to save session '" .. name .. "': " .. err_msg)
    return false
  end
end

-- セッションの読み込み
function M.load_session(name)
  if not Config.session.enabled then
    log.debug("Session functionality is disabled")
    return false
  end
  
  local db = get_db()
  if not db then
    return false
  end
  
  -- セッションの存在を確認
  local sessions = db:select("sessions", { where = { name = name } })
  if #sessions == 0 then
    log.warn("Session '" .. name .. "' not found")
    return false
  end
  
  local session_id = sessions[1].id
  
  -- バッファ情報を取得
  local buffers = db:select("session_buffers", {
    where = { session_id = session_id },
    order_by = "display_order"
  })
  
  if #buffers == 0 then
    log.warn("No buffers found in session '" .. name .. "'")
    return false
  end
  
  -- 現在の全バッファをクリア（オプション設定による）
  if Config.session.clear_buffers_on_load then
    log.debug("Clearing existing buffers")
    local current_buffers = vim.api.nvim_list_bufs()
    for _, buf in ipairs(current_buffers) do
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, 'modified') == false then
        vim.api.nvim_buf_delete(buf, { force = false })
      end
    end
  end
  
  -- バッファを読み込む
  local active_buffer = nil
  for _, buffer_info in ipairs(buffers) do
    -- ファイルが存在する場合のみ読み込み
    if vim.fn.filereadable(buffer_info.buffer_path) == 1 then
      local buf = vim.cmd("edit " .. vim.fn.fnameescape(buffer_info.buffer_path))
      
      -- アクティブバッファを記録
      if buffer_info.is_active then
        active_buffer = {
          buf = buf,
          cursor = buffer_info.cursor_position
        }
      end
    else
      log.warn("File not found: " .. buffer_info.buffer_path)
    end
  end
  
  -- アクティブバッファにカーソルを設定
  if active_buffer and active_buffer.cursor and active_buffer.cursor ~= "" then
    local row, col = string.match(active_buffer.cursor, "(%d+),(%d+)")
    if row and col then
      vim.api.nvim_win_set_cursor(0, { tonumber(row), tonumber(col) })
    end
  end
  
  log.info("Session '" .. name .. "' loaded successfully")
  return true
end

-- セッションの一覧を取得
function M.list_sessions()
  local db = get_db()
  if not db then
    return {}
  end
  
  local sessions = db:select("sessions", { order_by = "updated_at DESC" })
  return sessions
end

-- セッションの削除
function M.delete_session(name)
  local db = get_db()
  if not db then
    return false
  end
  
  local success = db:with_transaction(function()
    -- セッションの存在を確認
    local sessions = db:select("sessions", { where = { name = name } })
    if #sessions == 0 then
      log.warn("Session '" .. name .. "' not found")
      return false
    end
    
    local session_id = sessions[1].id
    
    -- セッションバッファを削除
    db:delete("session_buffers", { session_id = session_id })
    
    -- セッションを削除
    db:delete("sessions", { id = session_id })
    
    return true
  end)
  
  if success then
    log.info("Session '" .. name .. "' deleted successfully")
    return true
  else
    log.error("Failed to delete session '" .. name .. "'")
    return false
  end
end

-- 最後に更新されたセッションを自動的に読み込む
function M.auto_load_last_session()
  if not Config.session.enabled or not Config.session.auto_load then
    log.debug("Auto-load session is disabled")
    return false
  end
  
  local db = get_db()
  if not db then
    return false
  end
  
  local sessions = db:select("sessions", { 
    order_by = "updated_at DESC",
    limit = 1
  })
  
  if #sessions == 0 then
    log.debug("No sessions found for auto-load")
    return false
  end
  
  return M.load_session(sessions[1].name)
end

-- 自動保存機能
function M.setup_auto_save()
  if not Config.session.enabled or not Config.session.auto_save then
    log.debug("Auto-save session is disabled")
    return
  end
  
  -- 自動保存用のタイマーを設定
  local save_interval = Config.session.save_interval or 300 -- デフォルト5分
  
  -- タイマーが既に存在する場合はクリア
  if M._auto_save_timer then
    M._auto_save_timer:stop()
    M._auto_save_timer = nil
  end

  -- 新しいタイマーを設定
  M._auto_save_timer = vim.loop.new_timer()
  M._auto_save_timer:start(
    save_interval * 1000,  -- 最初の実行までの時間（ミリ秒）
    save_interval * 1000,  -- 定期的な実行間隔（ミリ秒）
    vim.schedule_wrap(function()
      M.save_session("auto_save")
    end)
  )
  
  -- 終了時の自動保存設定
  if Config.session.save_on_exit then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = vim.api.nvim_create_augroup("PileSessionAutoSave", { clear = true }),
      callback = function()
        M.save_session("auto_save")
      end,
    })
  end
  
  log.info("Auto-save session configured with interval: " .. save_interval .. "s")
end

-- 初期化関数
function M.setup()
  if not Config.session.enabled then
    log.debug("Session functionality is disabled")
    return
  end
  
  -- データベース接続を初期化
  local db = get_db()
  if not db then
    log.error("Failed to initialize SQLite database")
    return
  end
  
  -- 自動セッション機能の設定
  M.setup_auto_save()
  
  -- 自動読み込み
  if Config.session.auto_load then
    vim.defer_fn(function()
      M.auto_load_last_session()
    end, 100) -- 少し遅延させて他の初期化が完了してから実行
  end
  
  log.info("SQLite session manager initialized")
end

return M