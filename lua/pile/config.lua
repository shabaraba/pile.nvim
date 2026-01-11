-- setupで受け取るconfigはここ
local M = {
  debug = {
    enabled = false, -- デフォルトではデバッグログを無効化
    level = "info",  -- デバッグレベル: "error", "warn", "info", "debug", "trace"
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

  -- バッファハイライト設定
  M.buffer = {
    highlight = {
      current = {
        bg = "#3E4452",
        fg = "Red",
      },
    },
  }

  -- Git worktree display settings
  M.worktree = {
    enabled = true,  -- Enable worktree visual separation
    separator = {
      enabled = true,  -- Show separator lines between worktrees
      style = "─",  -- Character to use for separator line
      show_branch = true,  -- Show branch/worktree name in separator
    },
    highlight = {
      separator = {
        fg = "#61AFEF",  -- Blue color for separator
        bold = true,
      },
      branch = {
        fg = "#98C379",  -- Green color for branch name
        bold = true,
      },
    },
  }

  -- Apply user-provided worktree settings
  if opts and opts.worktree then
    if opts.worktree.enabled ~= nil then
      M.worktree.enabled = opts.worktree.enabled
    end
    if opts.worktree.separator then
      if opts.worktree.separator.enabled ~= nil then
        M.worktree.separator.enabled = opts.worktree.separator.enabled
      end
      if opts.worktree.separator.style ~= nil then
        M.worktree.separator.style = opts.worktree.separator.style
      end
      if opts.worktree.separator.show_branch ~= nil then
        M.worktree.separator.show_branch = opts.worktree.separator.show_branch
      end
    end
    if opts.worktree.highlight then
      if opts.worktree.highlight.separator then
        if opts.worktree.highlight.separator.fg ~= nil then
          M.worktree.highlight.separator.fg = opts.worktree.highlight.separator.fg
        end
        if opts.worktree.highlight.separator.bold ~= nil then
          M.worktree.highlight.separator.bold = opts.worktree.highlight.separator.bold
        end
      end
      if opts.worktree.highlight.branch then
        if opts.worktree.highlight.branch.fg ~= nil then
          M.worktree.highlight.branch.fg = opts.worktree.highlight.branch.fg
        end
        if opts.worktree.highlight.branch.bold ~= nil then
          M.worktree.highlight.branch.bold = opts.worktree.highlight.branch.bold
        end
      end
    end
  end

  -- その他の設定があれば追加
end

return M
