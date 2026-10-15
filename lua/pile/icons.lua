local M = {}

local provider = nil

local function mini_icons_provider()
  local ok, mini_icons = pcall(require, 'mini.icons')
  if not ok or not _G.MiniIcons then
    return nil
  end
  return function(path)
    local icon, hl = mini_icons.get('file', path)
    return icon, hl
  end
end

local function devicons_provider()
  local ok, devicons = pcall(require, 'nvim-web-devicons')
  if not ok then
    return nil
  end
  return function(path)
    local filename = vim.fn.fnamemodify(path, ':t')
    local extension = vim.fn.fnamemodify(path, ':e')
    return devicons.get_icon(filename, extension, { default = true })
  end
end

local function resolve_provider()
  if provider == nil then
    provider = mini_icons_provider() or devicons_provider() or false
  end
  return provider
end

--- Look up the file icon for a buffer path
--- Prefers mini.icons when it has been set up, then nvim-web-devicons.
--- @param path string
--- @return string|nil icon
--- @return string|nil hl_group
function M.get(path)
  local get_icon = resolve_provider()
  if not get_icon then
    return nil, nil
  end
  return get_icon(path)
end

return M
