local M = {}

local provider = nil
-- A path's icon never changes within a session, and lookups run on every redraw
local cache = {}

local function mini_icons_provider()
  if not _G.MiniIcons then
    return nil
  end
  return function(path)
    return _G.MiniIcons.get('file', path)
  end
end

local function devicons_provider()
  local ok, devicons = pcall(require, 'nvim-web-devicons')
  if not ok then
    return nil
  end
  return function(path)
    -- devicons derives the extension itself, including multi-dot ones like .d.ts
    return devicons.get_icon(vim.fs.basename(path), nil, { default = true })
  end
end

--- Look up the file icon for a buffer path
--- Prefers mini.icons when it has been set up, then nvim-web-devicons.
--- @param path string
--- @return string|nil icon
--- @return string|nil hl_group
function M.get(path)
  if provider == nil then
    provider = mini_icons_provider() or devicons_provider() or false
  end
  if not provider then
    return nil, nil
  end

  if not cache[path] then
    local icon, hl = provider(path)
    cache[path] = { icon, hl }
  end
  return cache[path][1], cache[path][2]
end

return M
