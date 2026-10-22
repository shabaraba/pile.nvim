local M = {}

local health = vim.health

local function check_neovim()
  if vim.fn.has("nvim-0.10") == 1 then
    health.ok("Neovim " .. tostring(vim.version()))
  else
    health.error("Neovim 0.10 or later is required", { "Upgrade Neovim" })
  end
end

local function check_dependencies()
  if pcall(require, "window-picker") then
    health.ok("s1n7ax/nvim-window-picker is installed")
  else
    health.error("s1n7ax/nvim-window-picker is not installed", {
      "It chooses the window a buffer opens in when several windows are open",
      "Add it to the plugin's dependencies in your plugin manager",
    })
  end

  if _G.MiniIcons then
    health.ok("File icons: mini.icons")
  elseif pcall(require, "nvim-web-devicons") then
    health.ok("File icons: nvim-web-devicons")
  else
    health.info("No icon provider found (mini.icons or nvim-web-devicons); icons are not shown")
  end

  if vim.fn.executable("git") == 1 then
    health.ok("git is executable")
  else
    health.warn("git is not executable", {
      "Git status marks are not shown and sessions are shared by all projects",
    })
  end
end

local function check_type(path, value, expected)
  if value ~= nil and type(value) ~= expected then
    health.error(string.format("%s must be a %s, got %s", path, expected, type(value)))
    return false
  end
  return true
end

local function check_patterns(rule, patterns)
  local valid = true
  for _, pattern in ipairs(patterns or {}) do
    local ok, err = pcall(string.match, "", pattern)
    if not ok then
      health.error(string.format("%s.filenames: invalid Lua pattern %q: %s", rule, pattern, err))
      valid = false
    end
  end
  return valid
end

local function check_config()
  local pile = require("pile")
  if not pile.is_initialized() then
    health.warn("pile.nvim is not initialized yet", {
      "It initializes itself after startup; if this persists, check that plugin/pile.lua is on 'runtimepath'",
    })
    return
  end

  local config = require("pile.config")
  local valid = true

  local booleans = {
    { "session.auto_save", config.session.auto_save },
    { "session.auto_restore", config.session.auto_restore },
    { "session.preserve_order", config.session.preserve_order },
    { "window_indicator.enabled", config.window_indicator.enabled },
    { "icons.enabled", config.icons.enabled },
    { "marks.modified", config.marks.modified },
    { "marks.git", config.marks.git },
    { "preview.auto_open", config.preview.auto_open },
    { "rename.confirm", config.rename.confirm },
    { "tabline.enabled", config.tabline.enabled },
  }
  for _, entry in ipairs(booleans) do
    valid = check_type(entry[1], entry[2], "boolean") and valid
  end

  valid = check_type("window_indicator.colors", config.window_indicator.colors, "table") and valid
  valid = check_type("window_picker", config.window_picker, "table") and valid

  for _, rule in ipairs({ "exclude", "include" }) do
    for _, field in ipairs({ "filenames", "filetypes", "buftypes" }) do
      valid = check_type(rule .. "." .. field, config[rule][field], "table") and valid
    end
    if type(config[rule].filenames) == "table" then
      valid = check_patterns(rule, config[rule].filenames) and valid
    end
  end

  if valid then
    health.ok("Configuration is valid")
  end

  if not config.session.preserve_order then
    health.info("session.preserve_order is false: reordering and :PileSort are disabled")
  end
end

local function check_storage()
  local dir = vim.fn.stdpath("data") .. "/pile"
  if vim.fn.isdirectory(dir) == 0 then
    health.info("Session directory does not exist yet: " .. dir)
  elseif vim.fn.filewritable(dir) == 2 then
    health.ok("Session directory is writable: " .. dir)
  else
    health.error("Session directory is not writable: " .. dir)
  end
end

function M.check()
  health.start("pile.nvim")
  check_neovim()
  check_dependencies()
  health.start("pile.nvim configuration")
  check_config()
  check_storage()
end

return M
