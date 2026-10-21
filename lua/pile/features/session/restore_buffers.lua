--- Add the saved buffers back
local log = require('pile.log')

local M = {}

--- Restore a buffer from a file path
--- The buffer is added but deliberately left unloaded: loading it here would fire
--- BufRead/FileType for every session file, dragging syntax, treesitter and LSP
--- attach into startup. Neovim loads it on first display instead.
--- @param path string File path to restore
--- @return number|nil Buffer handle if successful
local function restore_buffer(path)
  if not path or vim.fn.filereadable(path) ~= 1 then
    log.debug("File not readable: " .. (path or "nil"))
    return nil
  end

  local buf = vim.fn.bufadd(path)
  if buf > 0 then
    -- bufadd() leaves 'buflisted' off, which hides the buffer from :bnext/:bprev
    vim.bo[buf].buflisted = true
    log.trace("Restored buffer: " .. path)
    return buf
  end
  return nil
end

--- Close all empty nofile buffers
--- Removes buffers with no name and buftype='nofile' (e.g., startup buffers)
--- The sidebar's own scratch buffer matches too and is kept.
function M.close_empty_nofile()
  local sidebar_buf = require('pile.globals').sidebar_buf
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= sidebar_buf and vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      local buftype = vim.bo[buf].buftype
      if name == '' and buftype == 'nofile' then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end
end

--- @param buffers table[] Saved entries {path}, in the order to add them
--- @return table<string, number> buffer_map path -> buffer, for the files that could be added
--- @return number count
function M.add(buffers)
  local buffer_map, count = {}, 0
  for _, buf_data in ipairs(buffers) do
    local buf = restore_buffer(buf_data.path)
    if buf then
      count = count + 1
      buffer_map[buf_data.path] = buf
    end
  end
  return buffer_map, count
end

return M
