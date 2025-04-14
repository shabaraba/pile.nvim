local globals = require('pile.globals')
local window = require('pile.windows')
local popup = require('pile.windows.popup')
local log = require('pile.log')
local M = {}

local selected_buffer = nil

-- バッファが実際に表示されているかどうかを確認する関数
local function is_buffer_displayed(buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local win_buf = vim.api.nvim_win_get_buf(win)
      if win_buf == buf then
        return true
      end
    end
  end
  return false
end

-- oil.nvimの一時ディレクトリバッファかどうかを判定する関数
local function is_oil_temp_buffer(buf, name, filetype)
  -- oil.nvimのバッファは特定のfiletypeを持つ
  if filetype == 'oil' or filetype:match("^oil") then
    return true
  end
  
  -- oil.nvimが作成する一時的なバッファをパスパターンで判定
  if name:match("^oil://") then
    return true
  end
  
  return false
end

function M.get_list()
  local buffers = vim.api.nvim_list_bufs()
  local buffer_list = {}
  local filenames = {}

  -- デバッグ情報: 開いているバッファ一覧
  log.debug("全バッファリスト:")
  for i, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      log.debug(string.format("[%d] buf=%d, name=%s", i, buf, name))
    end
  end

  -- 最初に全バッファの情報を収集する（フィルタリングはまだ行わない）
  local all_buffer_info = {}
  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
      local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
      local name = vim.api.nvim_buf_get_name(buf)
      local base_filename = vim.fn.fnamemodify(name, ":t")
      
      -- この段階では、すべての有効なバッファ情報を保存
      table.insert(all_buffer_info, {
        buf = buf,
        name = name,
        base_filename = base_filename,
        buftype = buftype,
        filetype = filetype,
        displayed = is_buffer_displayed(buf)
      })
    end
  end
  
  -- バッファをフィルタリングして一覧に追加
  for _, info in ipairs(all_buffer_info) do
    -- デバッグ情報: 各バッファの詳細情報
    log.debug(string.format("バッファ詳細: buf=%d, buftype=%s, filetype=%s, name=%s, base_filename=%s, displayed=%s", 
                           info.buf, info.buftype, info.filetype, info.name, info.base_filename, 
                           info.displayed and "true" or "false"))
    
    -- 表示する必要のあるバッファだけをリストに追加
    -- 1. バッファに名前があること
    -- 2. ポップアップ、通知、特殊バッファでないこと
    -- 3. oil.nvimの一時バッファでないこと
    -- 4. 表示されているか、特定の条件を満たすバッファであること
    if info.name ~= "" and 
       info.buftype ~= 'popup' and 
       info.filetype ~= 'notify' and 
       info.buftype ~= 'nofile' and
       not is_oil_temp_buffer(info.buf, info.name, info.filetype) and
       (info.displayed or info.name:match("%.%w+$")) then -- 表示されているか、拡張子を持つファイル
      
      -- 同名ファイルの数をカウント
      filenames[info.base_filename] = (filenames[info.base_filename] or 0) + 1
      table.insert(buffer_list, { 
        buf = info.buf, 
        name = info.name, 
        filename = info.base_filename 
      })
      
      -- デバッグ情報: 初期バッファ追加時
      log.debug(string.format("追加したバッファ: buf=%d, name=%s, filename=%s", 
                              info.buf, info.name, info.base_filename))
    end
  end
  
  -- デバッグ情報: 同名ファイルの検出
  log.debug("同名ファイル検出結果:")
  for fname, count in pairs(filenames) do
    log.debug(string.format("ファイル名: %s, 出現回数: %d", fname, count))
  end

  -- 同名ファイルが複数ある場合は特別な処理をする
  if buffer_list and #buffer_list > 0 then
    -- まず同名ファイルをグループ化する
    local duplicate_groups = {}
    for _, buffer in ipairs(buffer_list) do
      if filenames[buffer.filename] > 1 then
        duplicate_groups[buffer.filename] = duplicate_groups[buffer.filename] or {}
        table.insert(duplicate_groups[buffer.filename], buffer)
      end
    end

    -- 同名ファイルグループごとに処理
    for filename, group in pairs(duplicate_groups) do
      log.debug(string.format("同名ファイルの処理: %s (%d個のファイル)", filename, #group))
      
      -- 改良されたパス表示アルゴリズム
      for _, buffer in ipairs(group) do
        -- 相対パスを取得（カレントディレクトリからの相対パス）
        local rel_path = vim.fn.fnamemodify(buffer.name, ":~:.")
        
        -- パスをセグメントに分割
        local segments = {}
        for segment in string.gmatch(rel_path, "[^/\\\\]+") do
          table.insert(segments, segment)
        end
        
        -- 少なくとも2つのセグメントがあれば（親ディレクトリがある）
        if #segments >= 2 then
          -- ファイル名を除く全てのパスセグメントを結合
          local path_prefix = table.concat(segments, "/", 1, #segments - 1)
          -- 表示名をディレクトリ/ファイル名の形式に
          buffer.filename = path_prefix .. "/" .. filename
          log.debug(string.format("ファイル '%s' のパス表示を '%s' に変更", buffer.name, buffer.filename))
        else
          -- パス情報が不足している場合は絶対パスを短縮して使用
          local short_path = vim.fn.pathshorten(vim.fn.fnamemodify(buffer.name, ":p"))
          buffer.filename = short_path
          log.debug(string.format("パス情報不足: ファイル '%s' のパス表示を '%s' に変更", buffer.name, buffer.filename))
        end
      end
    end
  end

  -- デバッグ情報: 同名ファイルの処理後、最終的なバッファリストを出力
  log.debug("Buffer List Results:")
  for i, buffer in ipairs(buffer_list) do
    log.debug(string.format("[%d] buf: %d, name: %s, filename: %s", 
                           i, buffer.buf, buffer.name, buffer.filename))
  end

  -- デバッグ情報: 処理後のバッファリスト内容を表示
  vim.defer_fn(function()
    log.debug("デバッグ: バッファリスト処理結果:")
    for i, buf in ipairs(buffer_list) do
      log.debug(string.format("[%d] buf=%d, filename=%s, name=%s", 
        i, buf.buf, buf.filename, buf.name))
    end
  end, 100)

  return buffer_list
end

function M.get_current()
  return vim.api.nvim_get_current_buf()
end

local function open_selected_callback(choice, idx)
  if choice then
    window.set_buffer(choice, selected_buffer.buf)
  end
  popup.unmount()
end

-- @param props {available_windows: list}
function M.open_selected(props)
  local cursor = vim.api.nvim_win_get_cursor(globals.sidebar_win)
  local line = cursor[1]
  selected_buffer = M.get_list()[line]
  if not selected_buffer then
    print("No buffer selected.")
    return
  end

  -- ウィンドウが1つしかない場合、自動的にそこに開く
  if #(props.available_windows) == 1 then
    window.set_buffer(props.available_windows[1], selected_buffer.buf)
  elseif #(props.available_windows) > 1 then
    popup.select_window(props.available_windows, open_selected_callback)
  else
    window.set_buffer(nil, selected_buffer.buf)
  end
end

function M.next()
  local buffers = M.get_list()
  local current_buf = M.get_current()
  for i, buffer in ipairs(buffers) do
    if buffer.buf == current_buf then
      local next_buf = buffers[i + 1] and buffers[i + 1].buf or buffers[1].buf
      vim.api.nvim_set_current_buf(next_buf)
      return
    end
  end
end

function M.prev()
  local buffers = M.get_list()
  local current_buf = M.get_current()
  for i, buffer in ipairs(buffers) do
    if buffer.buf == current_buf then
      local prev_buf = buffers[i - 1] and buffers[i - 1].buf or buffers[#buffers].buf
      vim.api.nvim_set_current_buf(prev_buf)
      return
    end
  end
end

return M
