local session_store = require('pile.storage.session_store')

local uv = vim.uv or vim.loop

local M = {}

local names_before_rename = {}

local function is_stored(path)
  if session_store.get_aliases()[path] then
    return true
  end
  for _, session in pairs(session_store.get_all_sessions()) do
    for _, entry in ipairs(session.buffers or {}) do
      if entry.path == path then
        return true
      end
    end
  end
  return false
end

--- Keep aliases and the stored order on a buffer renamed outside pile
--- (:saveas, :file, oil.nvim, LSP renames ...). Only buffer renames are seen;
--- files moved by a shell command keep their old entries until M.prune().
--- @param group number augroup
--- @param on_change fun() called after stored paths changed
function M.follow_buffer_renames(group, on_change)
  vim.api.nvim_create_autocmd("BufFilePre", {
    group = group,
    callback = function(ev)
      names_before_rename[ev.buf] = vim.api.nvim_buf_get_name(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufFilePost", {
    group = group,
    callback = function(ev)
      local from = names_before_rename[ev.buf]
      names_before_rename[ev.buf] = nil
      local to = vim.api.nvim_buf_get_name(ev.buf)
      if from and from ~= '' and to ~= '' and from ~= to and is_stored(from) then
        session_store.rename_paths({ [from] = to })
        on_change()
      end
    end,
  })
end

--- Remove aliases of paths that neither exist on disk nor are open as a buffer
--- @return number removed
function M.prune()
  local open = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    open[vim.api.nvim_buf_get_name(buf)] = true
  end

  local removed = {}
  for path in pairs(session_store.get_aliases()) do
    if not open[path] and not uv.fs_stat(path) then
      removed[path] = false
    end
  end

  local count = vim.tbl_count(removed)
  if count > 0 then
    session_store.update_aliases(removed)
  end
  return count
end

return M
