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

-- alpha.nvimの無効化（存在する場合）
local function disable_alpha_if_needed()
  -- この関数は不要になったため空実装
  log.debug("alpha.nvim無効化関数は現在無効化されています（スタートアップ画面との共存のため）")
  -- 実際には何もしない
end

-- セッションの読み込み前処理
local function prepare_for_session_load()
  -- この関数は不要になったため空実装
  log.debug("セッション読み込み前処理は現在無効化されています（スタートアップ画面との共存のため）")
  -- 実際には何もしない
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
  local sessions
  local success, result = pcall(function()
    return db:select("sessions", { where = { name = name } })
  end)
  
  if not success then
    local err_msg = type(result) == "string" and result or "Unknown error"
    log.error("Failed to query session: " .. err_msg)
    return false
  end
  
  sessions = result
  
  if #sessions == 0 then
    log.warn("Session '" .. name .. "' not found")
    return false
  end
  
  local session_id = sessions[1].id
  
  -- バッファ情報を取得
  local buffers
  success, result = pcall(function()
    return db:select("session_buffers", {
      where = { session_id = session_id },
      order_by = "display_order"
    })
  end)
  
  if not success then
    local err_msg = type(result) == "string" and result or "Unknown error"
    log.error("Failed to query session buffers: " .. err_msg)
    return false
  end
  
  buffers = result
  
  if #buffers == 0 then
    log.warn("No buffers found in session '" .. name .. "'")
    return false
  end
  
  log.debug("Found " .. #buffers .. " buffers to restore")
  
  -- 現在の全バッファをクリア（オプション設定による）
  -- スタートアップ画面の共存のため、この処理は行わない
  if Config.session.clear_buffers_on_load and false then
    log.debug("Clearing existing buffers")
    local current_buffers = vim.api.nvim_list_bufs()
    for _, buf in ipairs(current_buffers) do
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, 'modified') == false then
        pcall(vim.api.nvim_buf_delete, buf, { force = false })
      end
    end
  end
  
  -- バッファを読み込む
  local active_buffer = nil
  local loaded_buffers = {}
  
  for i, buffer_info in ipairs(buffers) do
    -- ファイルが存在する場合のみ読み込み
    if vim.fn.filereadable(buffer_info.buffer_path) == 1 then
      log.debug("Loading buffer: " .. buffer_info.buffer_path)
      
      -- まずバッファを作成（editではなくbadd）
      local buf_nr = vim.fn.bufadd(buffer_info.buffer_path)
      
      -- バッファを読み込み
      if buf_nr ~= -1 and not vim.api.nvim_buf_is_loaded(buf_nr) then
        -- bufloadはバッファを表示せずに読み込む
        vim.fn.bufload(buf_nr)
      end
      
      table.insert(loaded_buffers, {
        buf = buf_nr,
        is_active = buffer_info.is_active,
        cursor = buffer_info.cursor_position,
        path = buffer_info.buffer_path,
      })
      
      -- アクティブバッファを記録
      if buffer_info.is_active then
        active_buffer = loaded_buffers[#loaded_buffers]
      end
    else
      log.warn("File not found: " .. buffer_info.buffer_path)
    end
  end
  
  if #loaded_buffers == 0 then
    log.warn("No buffers were loaded from session - all files missing?")
    return false
  end
  
  -- スタートアップ画面との共存のため、現在のウィンドウにバッファを表示しない
  -- バッファは読み込むだけにして、pile.nvimのサイドバーでバッファを選択したときに表示するようにする
  if false and active_buffer then
    -- アクティブバッファを現在のウィンドウに表示
    pcall(vim.api.nvim_set_current_buf, active_buffer.buf)
    
    -- カーソル位置を設定
    if active_buffer.cursor and active_buffer.cursor ~= "" then
      local row, col = string.match(active_buffer.cursor, "(%d+),(%d+)")
      if row and col then
        -- カーソル位置の設定を試みる
        pcall(function()
          vim.api.nvim_win_set_cursor(0, { tonumber(row), tonumber(col) })
        end)
      end
    end
  end
  
  -- セッションが読み込まれたフラグを設定
  M._session_loaded = true
  M._loaded_buffers = loaded_buffers -- バッファ情報を保存
  
  log.info("Session '" .. name .. "' loaded successfully with " .. #loaded_buffers .. " buffers")
  return true
end

-- 最後に更新されたセッションを自動的に読み込む
function M.auto_load_last_session()
  if not Config.session.enabled or not Config.session.auto_load then
    log.debug("Auto-load session is disabled")
    return false
  end
  
  local db = get_db()
  if not db then
    log.error("Failed to get database connection for auto-load")
    return false
  end
  
  -- 最新のセッションを取得
  local sessions
  local success, result = pcall(function()
    return db:select("sessions", { 
      order_by = "updated_at DESC",
      limit = 1
    })
  end)
  
  if not success then
    local err_msg = type(result) == "string" and result or "Unknown error"
    log.error("Failed to query sessions: " .. err_msg)
    return false
  end
  
  sessions = result
  
  if #sessions == 0 then
    log.debug("No sessions found for auto-load")
    return false
  end
  
  log.info("Auto-loading last session: " .. sessions[1].name)
  return M.load_session(sessions[1].name)
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
      log.debug("Auto-saving session...")
      M.save_session("auto_save")
    end)
  )
  
  -- 終了時の自動保存設定
  if Config.session.save_on_exit then
    -- 既存のautocommandをクリア
    local group = vim.api.nvim_create_augroup("PileSessionAutoSave", { clear = true })
    
    -- VimLeavePre よりも早いタイミングで発火する QuitPre を追加
    vim.api.nvim_create_autocmd({"VimLeavePre", "QuitPre"}, {
      group = group,
      callback = function()
        log.info("Saving session before exit...")
        local success = M.save_session("auto_save")
        if success then
          log.info("Exit session saved successfully")
        else
          log.error("Failed to save exit session")
        end
      end,
      desc = "Save pile.nvim session on exit",
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
  
  -- 自動読み込み - より早いタイミングで実行
  if Config.session.auto_load then
    -- VimEnterより前のUIReady/BaseLoadedなどのイベントを使用
    -- UIReadyはVimEnterよりも早く発火するイベント (Neovim 0.8+)
    local event = "UIEnter" -- Neovim 0.8未満の場合
    if vim.fn.has("nvim-0.8") == 1 then
      event = "UIReady" -- Neovim 0.8以上の場合
    end
    
    local group = vim.api.nvim_create_augroup("PileSessionAutoLoad", { clear = true })
    vim.api.nvim_create_autocmd(event, {
      group = group,
      callback = function()
        -- 起動引数でファイルが指定されていない場合のみ自動読み込み
        if vim.fn.argc() == 0 then
          log.info("Triggering auto-load of session (early) on " .. event .. "...")
          
          -- バックグラウンドでセッションを読み込む（スタートアップ画面を妨げない）
          vim.defer_fn(function()
            local loaded = M.auto_load_last_session()
            
            if loaded then
              -- 控えめな通知でセッション読み込み完了を知らせる
              vim.defer_fn(function()
                vim.notify("Pile: バッファのセッションを復元しました。サイドバーを開いて確認できます。", vim.log.levels.INFO)
              end, 100)
            end
          end, 50)
        else
          log.debug("Skipping auto-load because files were specified in command line")
        end
      end,
      desc = "Auto-load pile.nvim session (early)",
      once = true, -- 一度だけ実行
    })
    
    -- 追加のフォールバック - VimEnterでも実行（念のため）
    vim.api.nvim_create_autocmd("VimEnter", {
      group = group,
      callback = function()
        -- 起動引数でファイルが指定されていない場合のみ自動読み込み
        if vim.fn.argc() == 0 and not M._session_loaded then
          log.info("Fallback: Triggering auto-load of session on VimEnter...")
          
          -- バックグラウンドでセッションを読み込む
          vim.defer_fn(function()
            M.auto_load_last_session()
          end, 50)
        end
      end,
      desc = "Auto-load pile.nvim session (fallback)",
      once = true, -- 一度だけ実行
    })
  end
  
  log.info("SQLite session manager initialized")
end

return M