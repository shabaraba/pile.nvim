local Config = require("pile.config")
local buffers = require("pile.buffers")
local sidebar = require("pile.windows.sidebar")
local log = require("pile.log")
local sqlite = require("pile.repositories.sqlite")

local M = {}

-- nui.nvimの依存関係をチェック
local function check_dependencies()
  log.trace("Checking dependencies...")
  local has_nui, nui = pcall(require, "nui.popup")
  if not has_nui then
    log.error("Required dependency nui.nvim not found. Please install it with your plugin manager.")
    vim.notify(
      "pile.nvim requires nui.nvim to be installed. Please add it to your plugin manager.",
      vim.log.levels.ERROR
    )
    return false
  end
  
  -- セッション機能が有効ならSQLiteの依存関係をチェック
  if Config.session and Config.session.enabled then
    local has_sqlite, _ = pcall(require, "sqlite")
    if not has_sqlite then
      log.warn("SQLite support is enabled, but sqlite.lua is not installed. Session functionality will be disabled.")
      vim.notify(
        "pile.nvim: Session functionality requires sqlite.lua, please install it to use sessions.",
        vim.log.levels.WARN
      )
      Config.session.enabled = false
    end
  end
  
  log.trace("All dependencies found")
  return true
end

---@param opts Config
function M.setup(opts)
  -- 依存関係のチェック
  if not check_dependencies() then
    return
  end
  
  Config.setup(opts)

  -- ハイライトグループを定義（新しいAPIを使用）
  vim.api.nvim_set_hl(0, "SidebarCurrentBuffer", {
    bg = Config.buffer.highlight.current.bg,
    fg = Config.buffer.highlight.current.fg,
  })
  vim.api.nvim_set_hl(0, "SelectedWindow", {
    bg = "Red",
    fg = "White",
  })

  -- 基本コマンドの登録
  vim.api.nvim_create_user_command("PileToggle", M.toggle_sidebar, { desc = "toggle pile window" })
  vim.api.nvim_create_user_command("PileGoToNextBuffer", M.switch_to_next_buffer, { desc = "go to next buffer" })
  vim.api.nvim_create_user_command("PileGoToPrevBuffer", M.switch_to_prev_buffer, { desc = "go to prev buffer" })
  
  -- セッション関連コマンドの登録
  if Config.session.enabled then
    vim.api.nvim_create_user_command("PileSaveSession", function(opts)
      local name = opts.args ~= "" and opts.args or "default"
      sqlite.save_session(name)
    end, { nargs = "?", desc = "save current session" })
    
    vim.api.nvim_create_user_command("PileLoadSession", function(opts)
      local name = opts.args ~= "" and opts.args or "default"
      sqlite.load_session(name)
    end, { nargs = "?", desc = "load a session" })
    
    vim.api.nvim_create_user_command("PileListSessions", function()
      local sessions = sqlite.list_sessions()
      if #sessions == 0 then
        vim.notify("No saved sessions found", vim.log.levels.INFO)
        return
      end
      
      local lines = {"Saved Sessions:"}
      for i, session in ipairs(sessions) do
        table.insert(lines, string.format("%d. %s (updated: %s)", i, session.name, session.updated_at))
      end
      
      vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    end, { desc = "list all saved sessions" })
    
    vim.api.nvim_create_user_command("PileDeleteSession", function(opts)
      if opts.args == "" then
        vim.notify("Error: Session name required", vim.log.levels.ERROR)
        return
      end
      sqlite.delete_session(opts.args)
    end, { nargs = 1, desc = "delete a saved session" })
    
    -- セッション機能の初期化
    sqlite.setup()
  end
end

function M.toggle_sidebar()
  sidebar.toggle()
end

-- 現在のバッファを一つ下のバッファに切り替える関数
function M.switch_to_next_buffer()
  buffers.next()
end

-- 現在のバッファを一つ上のバッファに切り替える関数
function M.switch_to_prev_buffer()
  buffers.prev()
end

return M
