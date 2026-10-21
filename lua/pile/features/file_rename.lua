local log = require('pile.log')

local uv = vim.uv or vim.loop

local M = {}

local LSP_TIMEOUT_MS = 3000
local HAS_CLIENT_METHODS = vim.fn.has('nvim-0.11') == 1

--- Call a client method; Neovim 0.11 turned them from functions into methods
local function call(client, method, ...)
  if HAS_CLIENT_METHODS then
    return client[method](client, ...)
  end
  return client[method](...)
end

local function clients_supporting(operation)
  local result = {}
  for _, client in ipairs((vim.lsp.get_clients or vim.lsp.get_active_clients)()) do
    local workspace = (client.server_capabilities or {}).workspace
    if workspace and workspace.fileOperations and workspace.fileOperations[operation] then
      table.insert(result, client)
    end
  end
  return result
end

local function to_lsp_files(changes)
  local files = {}
  for _, change in ipairs(changes) do
    table.insert(files, { oldUri = vim.uri_from_fname(change.from), newUri = vim.uri_from_fname(change.to) })
  end
  return files
end

--- Ask language servers for the edits (e.g. import paths) a rename implies
--- Requests go out together so the wait is one timeout, not one per server.
local function lsp_will_rename(files)
  local clients = clients_supporting('willRename')
  local pending = #clients
  local responses = {}

  for _, client in ipairs(clients) do
    call(client, 'request', 'workspace/willRenameFiles', { files = files }, function(err, result)
      responses[client] = { err = err, result = result }
      pending = pending - 1
    end)
  end
  vim.wait(LSP_TIMEOUT_MS, function() return pending == 0 end)

  for client, response in pairs(responses) do
    if response.result then
      vim.lsp.util.apply_workspace_edit(response.result, client.offset_encoding)
    elseif response.err then
      log.warn('willRenameFiles failed for ' .. client.name .. ': ' .. vim.inspect(response.err))
    end
  end
end

local function lsp_did_rename(files)
  for _, client in ipairs(clients_supporting('didRename')) do
    call(client, 'notify', 'workspace/didRenameFiles', { files = files })
  end
end

local function is_same_file(a, b)
  local stat_a, stat_b = uv.fs_stat(a), uv.fs_stat(b)
  return stat_a and stat_b and stat_a.ino == stat_b.ino and stat_a.dev == stat_b.dev
end

--- @param changes { buf: number, from: string, to: string }[]
--- @return string|nil error
function M.validate(changes)
  local targets = {}
  for _, change in ipairs(changes) do
    if targets[change.to] then
      return 'Two buffers would be renamed to ' .. change.to
    end
    targets[change.to] = true

    -- Case-only renames on case-insensitive filesystems see the target as existing
    if uv.fs_stat(change.to) and not is_same_file(change.from, change.to) then
      return change.to .. ' already exists'
    end
    if vim.api.nvim_buf_is_loaded(change.buf) and vim.bo[change.buf].modified then
      return vim.fn.fnamemodify(change.from, ':.') .. ' has unsaved changes; write it first'
    end
  end
  return nil
end

local function rename_one(change)
  vim.fn.mkdir(vim.fs.dirname(change.to), 'p')
  if uv.fs_stat(change.from) then
    local ok, err = uv.fs_rename(change.from, change.to)
    if not ok then
      return err
    end
  end

  vim.api.nvim_buf_set_name(change.buf, change.to)
  if vim.api.nvim_buf_is_loaded(change.buf) then
    -- After a name change Vim refuses a plain :write (E13). Writing once clears
    -- that; noautocmd keeps format-on-save and similar hooks out of a rename.
    vim.api.nvim_buf_call(change.buf, function()
      vim.cmd('silent noautocmd write!')
    end)
  end
  return nil
end

--- Rename files on disk and their buffers, letting language servers update references
--- Expects changes that already passed M.validate(). Stored order and aliases follow the
--- renamed buffers through the BufFilePost hook in features/aliases.lua.
--- @param changes { buf: number, from: string, to: string }[]
--- @return string|nil error
function M.apply(changes)
  lsp_will_rename(to_lsp_files(changes))

  local renamed, err = {}, nil
  for _, change in ipairs(changes) do
    err = rename_one(change)
    if err then
      break
    end
    table.insert(renamed, change)
  end

  if #renamed > 0 then
    lsp_did_rename(to_lsp_files(renamed))
  end
  return err
end

return M
