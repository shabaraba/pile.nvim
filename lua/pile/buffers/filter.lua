local config = require('pile.config')

local M = {}

local function is_oil_buffer(name, filetype)
  return filetype == 'oil' or filetype:match("^oil") or name:match("^oil://")
end

local function contains(list, value)
  return vim.tbl_contains(list or {}, value)
end

local warned_patterns = {}

local function matches_pattern(name, pattern)
  local ok, matched = pcall(string.match, name, pattern)
  if ok then
    return matched ~= nil
  end
  if not warned_patterns[pattern] then
    warned_patterns[pattern] = true
    vim.notify(("[pile.nvim] Ignoring invalid filename pattern %q: %s"):format(pattern, matched), vim.log.levels.WARN)
  end
  return false
end

local function matches_any_pattern(patterns, name)
  for _, pattern in ipairs(patterns or {}) do
    if matches_pattern(name, pattern) then
      return true
    end
  end
  return false
end

local function matches_rule(rule, name, buftype, filetype)
  if not rule then
    return false
  end
  return matches_any_pattern(rule.filenames, name)
    or contains(rule.filetypes, filetype)
    or contains(rule.buftypes, buftype)
end

--- Unlisted buffers are internal to plugins (pickers, help, ...) and stay hidden unless
--- `include` opts them in. Buffers restored from a session are listed but not yet loaded.
function M.is_trackable_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  if vim.bo[buf].buflisted then
    return true
  end
  return vim.api.nvim_buf_is_loaded(buf)
    and matches_rule(config.include, vim.api.nvim_buf_get_name(buf), vim.bo[buf].buftype, vim.bo[buf].filetype)
end

function M.is_displayable_buffer(info)
  return info.filename ~= ""
    and info.buftype ~= 'popup'
    and info.filetype ~= 'notify'
    and info.buftype ~= 'nofile'
    and not is_oil_buffer(info.name, info.filetype)
    and not matches_rule(config.exclude, info.name, info.buftype, info.filetype)
end

return M
