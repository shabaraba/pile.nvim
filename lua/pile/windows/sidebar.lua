local globals = require 'pile.globals'
local buffers = require 'pile.buffers'
local log = require 'pile.log'
local config = require 'pile.config'
local git = require 'pile.git'

local buffer_list = {}
-- Map from display line number to buffer index in buffer_list
local line_to_buffer = {}

local M = {}

local function create_sidebar()
  globals.sidebar_buf = vim.api.nvim_create_buf(false, true)
  vim.cmd('topleft vsplit')
  globals.sidebar_win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(globals.sidebar_win, globals.sidebar_buf)
  vim.api.nvim_win_set_width(globals.sidebar_win, 30)
end

local function set_buffer_lines()
  local lines = {}
  line_to_buffer = {}

  buffer_list = buffers.get_list()

  -- デバッグ情報: サイドバーに表示する前のバッファリスト
  log.debug("Sidebar Buffer List Before Display:")
  for i, buffer in ipairs(buffer_list) do
    log.debug(string.format("[%d] buf: %d, name: %s, filename: %s, worktree: %s",
                           i, buffer.buf, buffer.name, buffer.filename,
                           buffer.worktree and git.get_worktree_display_name(buffer.worktree) or "none"))
  end

  -- Check if worktree grouping is enabled
  if config.worktree and config.worktree.enabled then
    -- Group buffers by worktree
    local worktree_groups = {}
    local worktree_order = {}

    for i, buffer in ipairs(buffer_list) do
      local wt_key = "none"
      if buffer.worktree then
        wt_key = buffer.worktree.path
      end

      if not worktree_groups[wt_key] then
        worktree_groups[wt_key] = {
          worktree = buffer.worktree,
          buffers = {},
          indices = {}
        }
        table.insert(worktree_order, wt_key)
      end

      table.insert(worktree_groups[wt_key].buffers, buffer)
      table.insert(worktree_groups[wt_key].indices, i)
    end

    -- Build lines with worktree separators
    local line_num = 1
    for group_idx, wt_key in ipairs(worktree_order) do
      local group = worktree_groups[wt_key]

      -- Add separator line if enabled and not the first group
      if config.worktree.separator and config.worktree.separator.enabled then
        local separator_line = ""

        if config.worktree.separator.show_branch and group.worktree then
          local branch_name = git.get_worktree_display_name(group.worktree)
          local sep_char = config.worktree.separator.style or "─"
          local max_width = 28  -- Leave some padding
          local branch_text = " " .. branch_name .. " "
          local remaining_width = max_width - #branch_text

          if remaining_width > 0 then
            local left_width = math.floor(remaining_width / 2)
            local right_width = remaining_width - left_width
            separator_line = string.rep(sep_char, left_width) .. branch_text .. string.rep(sep_char, right_width)
          else
            separator_line = branch_text:sub(1, max_width)
          end
        else
          separator_line = string.rep(config.worktree.separator.style or "─", 28)
        end

        table.insert(lines, separator_line)
        -- Separator lines don't map to any buffer
        line_to_buffer[line_num] = nil
        line_num = line_num + 1
      end

      -- Add buffer lines for this worktree
      for buf_idx, buffer in ipairs(group.buffers) do
        table.insert(lines, buffer.filename)
        -- Map this line to the original buffer index
        line_to_buffer[line_num] = group.indices[buf_idx]
        line_num = line_num + 1
      end
    end
  else
    -- No worktree grouping - display buffers as before
    for i, buffer in ipairs(buffer_list) do
      table.insert(lines, buffer.filename)
      line_to_buffer[i] = i
    end
  end

  vim.api.nvim_buf_set_lines(globals.sidebar_buf, 0, -1, false, lines)

  -- デバッグ情報: 実際にサイドバーに表示された内容
  local displayed_lines = vim.api.nvim_buf_get_lines(globals.sidebar_buf, 0, -1, false)
  log.debug("Sidebar Displayed Lines:")
  for i, line in ipairs(displayed_lines) do
    log.debug(string.format("[%d] %s (maps to buffer %s)", i, line, line_to_buffer[i] or "separator"))
  end
end

local function highlight_buffer(target_buffer)
  buffer_list = buffers.get_list()

  -- Find which display line corresponds to the target buffer
  for display_line, buffer_idx in pairs(line_to_buffer) do
    if buffer_idx and buffer_list[buffer_idx] and buffer_list[buffer_idx].buf == target_buffer then
      vim.api.nvim_buf_add_highlight(globals.sidebar_buf, -1, "SidebarCurrentBuffer", display_line - 1, 0, -1)
    end
  end

  -- Apply worktree separator highlighting if enabled
  if config.worktree and config.worktree.enabled and config.worktree.separator and config.worktree.separator.enabled then
    for display_line = 1, vim.api.nvim_buf_line_count(globals.sidebar_buf) do
      if not line_to_buffer[display_line] then
        -- This is a separator line
        vim.api.nvim_buf_add_highlight(globals.sidebar_buf, -1, "PileWorktreeSeparator", display_line - 1, 0, -1)
      end
    end
  end
end

local function set_keymaps()
  vim.keymap.set('n', '<CR>', function()
    local current_win = vim.api.nvim_get_current_win()
    local current_line = vim.api.nvim_win_get_cursor(current_win)[1]
    local buffer_idx = line_to_buffer[current_line]

    if not buffer_idx then
      -- Cursor is on a separator line, do nothing
      return
    end

    local available_windows = require('pile.windows').get_available_windows()
    require 'pile.buffers'.open_selected({ available_windows = available_windows, line = buffer_idx })
  end, { buffer = globals.sidebar_buf, noremap = true, silent = true })

  vim.keymap.set('n', 'dd', function()
    local current_win = vim.api.nvim_get_current_win()
    local current_line = vim.api.nvim_win_get_cursor(current_win)[1]
    local buffer_idx = line_to_buffer[current_line]

    log.info(string.format("Current line: %d, buffer_idx: %s", current_line, buffer_idx or "none"))

    if not buffer_idx then
      -- Cursor is on a separator line, do nothing
      return
    end

    local buffer = buffer_list[buffer_idx]
    if buffer then
      vim.api.nvim_buf_delete(buffer.buf, { force = true })
      M.update()
    end
  end, { buffer = globals.sidebar_buf, noremap = true, silent = true })

  vim.keymap.set('x', 'd', function()
    local start_line = vim.fn.getpos('v')[2] -- bufnr, lnum, col, offのテーブル, vはビジュアルモードの選択開始位置
    local end_line = vim.fn.getpos('.')[2] -- bufnr, lnum, col, offのテーブル, .はビジュアルモードの選択終了位置

    for line = start_line, end_line do
      local buffer_idx = line_to_buffer[line]
      if buffer_idx then
        local selected_buffer = buffer_list[buffer_idx]
        if selected_buffer then
          vim.api.nvim_buf_delete(selected_buffer.buf, { force = true })
        end
      end
    end
    M.update()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true) -- ビジュアルモードを抜ける
  end, { buffer = globals.sidebar_buf, noremap = true, silent = true })
end

function M.open()
  if M.is_opened() then
    print("Sidebar already open.")
    return
  end

  create_sidebar()
  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', true)
  set_buffer_lines()
  highlight_buffer(buffers.get_current())
  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', false)

  set_keymaps()
end

function M.is_opened()
  return globals.sidebar_win and vim.api.nvim_win_is_valid(globals.sidebar_win)
end

function M.close()
  if M.is_opened() then
    vim.api.nvim_win_close(globals.sidebar_win, true)
    globals.sidebar_win = nil
    globals.sidebar_buf = nil
  else
    print("No sidebar to close.")
  end
end

function M.toggle()
  if M.is_opened() then
    M.close()
  else
    M.open()
  end
end

-- サイドバーを更新する関数
function M.update()
  if not globals.sidebar_buf or not vim.api.nvim_buf_is_valid(globals.sidebar_buf) then
    return
  end

  buffer_list = buffers.get_list()
  line_to_buffer = {}

  -- デバッグ情報: 更新時のバッファリスト
  log.debug("Update: Buffer List Before Display:")
  for i, buffer in ipairs(buffer_list) do
    log.debug(string.format("[%d] buf: %d, name: %s, filename: %s, worktree: %s",
                           i, buffer.buf, buffer.name, buffer.filename,
                           buffer.worktree and git.get_worktree_display_name(buffer.worktree) or "none"))
  end

  local lines = {}

  -- Check if worktree grouping is enabled
  if config.worktree and config.worktree.enabled then
    -- Group buffers by worktree
    local worktree_groups = {}
    local worktree_order = {}

    for i, buffer in ipairs(buffer_list) do
      local wt_key = "none"
      if buffer.worktree then
        wt_key = buffer.worktree.path
      end

      if not worktree_groups[wt_key] then
        worktree_groups[wt_key] = {
          worktree = buffer.worktree,
          buffers = {},
          indices = {}
        }
        table.insert(worktree_order, wt_key)
      end

      table.insert(worktree_groups[wt_key].buffers, buffer)
      table.insert(worktree_groups[wt_key].indices, i)
    end

    -- Build lines with worktree separators
    local line_num = 1
    for group_idx, wt_key in ipairs(worktree_order) do
      local group = worktree_groups[wt_key]

      -- Add separator line if enabled
      if config.worktree.separator and config.worktree.separator.enabled then
        local separator_line = ""

        if config.worktree.separator.show_branch and group.worktree then
          local branch_name = git.get_worktree_display_name(group.worktree)
          local sep_char = config.worktree.separator.style or "─"
          local max_width = 28  -- Leave some padding
          local branch_text = " " .. branch_name .. " "
          local remaining_width = max_width - #branch_text

          if remaining_width > 0 then
            local left_width = math.floor(remaining_width / 2)
            local right_width = remaining_width - left_width
            separator_line = string.rep(sep_char, left_width) .. branch_text .. string.rep(sep_char, right_width)
          else
            separator_line = branch_text:sub(1, max_width)
          end
        else
          separator_line = string.rep(config.worktree.separator.style or "─", 28)
        end

        table.insert(lines, separator_line)
        -- Separator lines don't map to any buffer
        line_to_buffer[line_num] = nil
        line_num = line_num + 1
      end

      -- Add buffer lines for this worktree
      for buf_idx, buffer in ipairs(group.buffers) do
        table.insert(lines, buffer.filename)
        -- Map this line to the original buffer index
        line_to_buffer[line_num] = group.indices[buf_idx]
        line_num = line_num + 1
      end
    end
  else
    -- No worktree grouping - display buffers as before
    for i, buffer in ipairs(buffer_list) do
      table.insert(lines, buffer.filename)
      line_to_buffer[i] = i
    end
  end

  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(globals.sidebar_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(globals.sidebar_buf, 'modifiable', false)

  -- デバッグ情報: 更新後のサイドバー表示内容
  local displayed_lines = vim.api.nvim_buf_get_lines(globals.sidebar_buf, 0, -1, false)
  log.debug("Update: Sidebar Displayed Lines:")
  for i, line in ipairs(displayed_lines) do
    log.debug(string.format("[%d] %s (maps to buffer %s)", i, line, line_to_buffer[i] or "separator"))
  end

  -- 現在のバッファをハイライト
  local current_buf = vim.api.nvim_get_current_buf()
  for display_line, buffer_idx in pairs(line_to_buffer) do
    if buffer_idx and buffer_list[buffer_idx] then
      log.debug(string.format("Comparing buffer: %d with current: %d", buffer_list[buffer_idx].buf, current_buf))
      if buffer_list[buffer_idx].buf == current_buf then
        log.debug("Found current buffer for highlighting")
        vim.api.nvim_buf_add_highlight(globals.sidebar_buf, -1, "SidebarCurrentBuffer", display_line - 1, 0, -1)
      end
    end
  end

  -- Apply worktree separator highlighting if enabled
  if config.worktree and config.worktree.enabled and config.worktree.separator and config.worktree.separator.enabled then
    for display_line = 1, vim.api.nvim_buf_line_count(globals.sidebar_buf) do
      if not line_to_buffer[display_line] then
        -- This is a separator line
        vim.api.nvim_buf_add_highlight(globals.sidebar_buf, -1, "PileWorktreeSeparator", display_line - 1, 0, -1)
      end
    end
  end

  if globals.sidebar_win and vim.api.nvim_win_is_valid(globals.sidebar_win) then
    vim.api.nvim_win_set_width(globals.sidebar_win, 30)
  end
end

-- 自動的にバッファが追加・変更・選択されたらサイドバーを更新する
vim.api.nvim_create_autocmd("BufAdd", {
  pattern = "*",
  callback = function()
    log.debug("BufAdd event - updating sidebar")
    M.update()
  end
})

vim.api.nvim_create_autocmd("BufLeave", {
  pattern = "*",
  callback = function()
    log.debug("BufLeave event - updating sidebar")
    M.update()
  end
})

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  callback = function()
    if vim.api.nvim_get_current_buf() ~= globals.sidebar_buf then
      log.debug("BufEnter event - updating sidebar")
      M.update()
    end
  end
})

-- oil.nvimでファイルを開いた後に特別な更新を行う
vim.api.nvim_create_autocmd("FileType", {
  pattern = {"*"},
  callback = function(ev)
    if ev.match ~= "oil" and ev.match ~= "oilBrowser" then
      log.debug("New file opened - updating sidebar with delay to catch oil.nvim changes")
      vim.defer_fn(function() 
        M.update() 
      end, 200) -- 少し遅延させてoil.nvimの処理完了を待つ
    end
  end
})

return M
