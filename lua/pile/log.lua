local config = require('pile.config')

local M = {}

-- ログレベルの定義
local LOG_LEVELS = {
  error = 1,
  warn = 2,
  info = 3,
  debug = 4,
  trace = 5
}

-- 現在の設定レベルに基づいてログを表示するかどうかの判定
local function should_log(level)
  -- デバッグが無効の場合、常にfalse
  if not config.debug.enabled then
    return false
  end

  -- 数値に変換したレベルで比較
  local config_level = LOG_LEVELS[config.debug.level] or LOG_LEVELS.info
  local requested_level = LOG_LEVELS[level] or LOG_LEVELS.info
  
  return requested_level <= config_level
end

-- ログ関数
local function log(level, ...)
  if not should_log(level) then
    return
  end
  
  local args = {...}
  local msg = ""
  
  for i, v in ipairs(args) do
    if type(v) == "table" then
      msg = msg .. vim.inspect(v) .. " "
    else
      msg = msg .. tostring(v) .. " "
    end
  end
  
  vim.notify("[pile.nvim][" .. level .. "] " .. msg, vim.log.levels[string.upper(level)] or vim.log.levels.INFO)
end

-- 各ログレベルの関数
function M.error(...) log("error", ...) end
function M.warn(...) log("warn", ...) end
function M.info(...) log("info", ...) end
function M.debug(...) log("debug", ...) end
function M.trace(...) log("trace", ...) end

return M
