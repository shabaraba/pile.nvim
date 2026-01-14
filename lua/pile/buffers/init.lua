local globals = require('pile.globals')
local window = require('pile.windows')
local popup = require('pile.windows.popup')
local log = require('pile.log')
local M = {}

local selected_buffer = nil

-- バッファが実際に表示されているすべてのウィンドウIDを返す関数
local function get_buffer_windows(buf)
  local windows = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local win_buf = vim.api.nvim_win_get_buf(win)
      -- サイドバーウィンドウとサイドバーバッファを除外
      if win_buf == buf and win ~= globals.sidebar_win and win_buf ~= globals.sidebar_buf then
        table.insert(windows, win)
      end
    end
  end
  return windows
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

  -- 最初に全バッファの情報を収集
  local all_buffer_info = {}
  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
      local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
      local name = vim.api.nvim_buf_get_name(buf)
      local filename = vim.fn.fnamemodify(name, ":t")
      
      -- この段階では、すべての有効なバッファ情報を保存
      local window_ids = get_buffer_windows(buf)
      table.insert(all_buffer_info, {
        buf = buf,
        name = name,
        filename = filename,
        buftype = buftype,
        filetype = filetype,
        displayed = #window_ids > 0,
        window_ids = window_ids
      })
    end
  end
  
  -- バッファをフィルタリングして一覧に追加
  for _, info in ipairs(all_buffer_info) do
    -- デバッグ情報: 各バッファの詳細情報
    log.debug(string.format("バッファ詳細: buf=%d, buftype=%s, filetype=%s, name=%s, filename=%s, displayed=%s", 
                           info.buf, info.buftype, info.filetype, info.name, info.filename, 
                           info.displayed and "true" or "false"))
    
    -- 表示する必要のあるバッファだけをリストに追加
    -- 1. バッファに名前があること
    -- 2. ポップアップ、通知、特殊バッファでないこと
    -- 3. oil.nvimの一時バッファでないこと
    -- 4. 表示されているか、特定の条件を満たすバッファであること
    if info.filename ~= "" and 
       info.buftype ~= 'popup' and 
       info.filetype ~= 'notify' and 
       info.buftype ~= 'nofile' and
       not is_oil_temp_buffer(info.buf, info.name, info.filetype) and
       (info.displayed or info.name:match("%.%w+$")) then -- 表示されているか、拡張子を持つファイル
      
      -- 同名ファイルの数をカウント
      filenames[info.filename] = (filenames[info.filename] or 0) + 1
      table.insert(buffer_list, {
        buf = info.buf,
        name = info.name,
        filename = info.filename,
        window_ids = info.window_ids
      })
      
      -- デバッグ情報: 初期バッファ追加時
      log.debug(string.format("追加したバッファ: buf=%d, name=%s, filename=%s", 
                             info.buf, info.name, info.filename))
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

    -- 同名ファイルの処理関数
    local function process_duplicate_files(filename, buffers_group)
      log.debug(string.format("同名ファイルの処理: %s (%d個のファイル)", filename, #buffers_group))
      
      -- パスをセグメントに分割して配列に格納
      local path_segments = {}
      for _, buffer in ipairs(buffers_group) do
        local segments = {}
        for segment in string.gmatch(buffer.name, "[^/\\\\]+") do
          table.insert(segments, segment)
        end
        path_segments[buffer.buf] = segments
        
        -- デバッグ用: パスセグメントを表示
        local segment_str = table.concat(segments, " > ")
        log.debug(string.format("バッファ %d のパスセグメント: %s", buffer.buf, segment_str))
      end
      
      -- 各バッファのパスを比較し、最小の差異を持つパス表現を生成
      for i, buffer1 in ipairs(buffers_group) do
        local segments1 = path_segments[buffer1.buf]
        
        -- 他のすべてのバッファと比較して一意な部分を見つける
        local unique_segments = {}
        for j = 1, #segments1 - 1 do -- 最後のセグメント（ファイル名）は除外
          local segment = segments1[j]
          local is_unique = true
          
          -- 他のバッファのパスにこのセグメントがあるか確認
          for k, buffer2 in ipairs(buffers_group) do
            if i ~= k then
              local segments2 = path_segments[buffer2.buf]
              for l = 1, #segments2 - 1 do
                if segments2[l] == segment then
                  is_unique = false
                  break
                end
              end
              if not is_unique then
                break
              end
            end
          end
          
          if is_unique then
            table.insert(unique_segments, { index = j, value = segment })
          end
        end
        
        -- 一意なセグメントが見つかった場合
        if #unique_segments > 0 then
          -- より上位のディレクトリを優先（パスの最初に近いもの）
          table.sort(unique_segments, function(a, b) return a.index < b.index end)
          local unique_segment = unique_segments[1].value
          
          -- 一意なセグメントを含む簡潔なパスを設定
          buffer1.filename = unique_segment .. "/" .. filename
          log.debug(string.format("バッファ %d に一意なパス '%s' を設定", buffer1.buf, buffer1.filename))
        else
          -- 一意なセグメントが見つからない場合、最後の2つのディレクトリを使用
          if #segments1 > 2 then
            local parent_dir = segments1[#segments1 - 1]
            if #segments1 > 3 then
              -- 2階層分のディレクトリを表示
              local grandparent_dir = segments1[#segments1 - 2]
              buffer1.filename = grandparent_dir .. "/" .. parent_dir .. "/" .. filename
            else
              -- 親ディレクトリのみ表示
              buffer1.filename = parent_dir .. "/" .. filename
            end
            log.debug(string.format("バッファ %d にパス '%s' を設定（一意なセグメントなし）", buffer1.buf, buffer1.filename))
          else
            -- パスが短すぎる場合はフルパスの相対表現を使用
            buffer1.filename = vim.fn.fnamemodify(buffer1.name, ":~:.")
            log.debug(string.format("バッファ %d にフルパス相対表現 '%s' を設定", buffer1.buf, buffer1.filename))
          end
        end
      end
      
      return true
    end
    
    -- グループ化された同名ファイルごとに処理を実行
    for filename, group in pairs(duplicate_groups) do
      -- 同名ファイル処理関数を呼び出す
      if not process_duplicate_files(filename, group) then
        -- 処理に失敗した場合はシンプルな相対パスを使用
        log.debug(string.format("ファイル '%s' の処理に失敗、標準的な相対パスを使用", filename))
        for _, buffer in ipairs(group) do
          buffer.filename = vim.fn.fnamemodify(buffer.name, ":~:.")
        end
      end
    end
  end

  -- デバッグ情報: 最終的なバッファリストを出力
  log.debug("最終的なバッファリスト:")
  for i, buffer in ipairs(buffer_list) do
    log.debug(string.format("[%d] buf: %d, name: %s, filename: %s", 
                           i, buffer.buf, buffer.name, buffer.filename))
  end

  -- 結果を返す
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
