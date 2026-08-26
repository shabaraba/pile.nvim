local log = require('pile.log')

local uv = vim.uv or vim.loop

local M = {}

function M.new(config)
  local self = {
    filepath = config.filepath,
    default_data = config.default_data or {},
  }

  -- Decoded contents, kept until the file changes on disk. read() runs on every
  -- sidebar update, so re-decoding the JSON each time is not affordable.
  local cache = nil
  local cache_mtime = nil

  local function file_mtime()
    local stat = uv.fs_stat(self.filepath)
    if not stat or not stat.mtime then
      return nil
    end
    return stat.mtime.sec * 1e9 + stat.mtime.nsec
  end

  local function ensure_directory()
    local dir = vim.fn.fnamemodify(self.filepath, ':h')
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, 'p')
      log.debug("Created directory: " .. dir)
    end
  end

  --- Drop the cached contents, forcing the next read() to hit disk
  function self.invalidate()
    cache = nil
    cache_mtime = nil
  end

  --- Read the stored contents
  --- The returned table is shared with the cache: treat it as read-only and go
  --- through update() to change anything.
  function self.read()
    local mtime = file_mtime()
    if cache and mtime and mtime == cache_mtime then
      return cache
    end

    if vim.fn.filereadable(self.filepath) == 0 then
      log.debug("File not found, using default data: " .. self.filepath)
      return vim.deepcopy(self.default_data)
    end

    local file = io.open(self.filepath, 'r')
    if not file then
      log.warn("Failed to open file: " .. self.filepath)
      return vim.deepcopy(self.default_data)
    end

    local content = file:read('*all')
    file:close()

    if not content or content == '' then
      log.debug("Empty file, using default data: " .. self.filepath)
      return vim.deepcopy(self.default_data)
    end

    local ok, data = pcall(vim.fn.json_decode, content)
    if not ok then
      log.error("Failed to decode JSON: " .. self.filepath)
      return vim.deepcopy(self.default_data)
    end

    log.trace("Read data from: " .. self.filepath)
    cache = data
    cache_mtime = mtime
    return data
  end

  function self.write(data)
    ensure_directory()

    local ok, json_string = pcall(vim.fn.json_encode, data)
    if not ok then
      log.error("Failed to encode JSON: " .. self.filepath)
      return false
    end

    -- Write to a sibling temp file and rename over the target. io.open(path, 'w')
    -- truncates immediately, so writing in place would destroy every saved session
    -- if the write then failed. rename() within a directory is atomic.
    local tmp_path = string.format('%s.%d.tmp', self.filepath, vim.fn.getpid())

    local file = io.open(tmp_path, 'w')
    if not file then
      log.error("Failed to open file for writing: " .. tmp_path)
      return false
    end

    local written, write_err = file:write(json_string)
    local closed, close_err = file:close()
    if not written or not closed then
      log.error("Failed to write file: " .. tmp_path .. ": " ..
        tostring(write_err or close_err))
      os.remove(tmp_path)
      return false
    end

    local renamed, rename_err = os.rename(tmp_path, self.filepath)
    if not renamed then
      log.error("Failed to replace file: " .. self.filepath .. ": " .. tostring(rename_err))
      os.remove(tmp_path)
      return false
    end

    cache = data
    cache_mtime = file_mtime()

    log.trace("Wrote data to: " .. self.filepath)
    return true
  end

  --- Read, transform and persist in one step
  --- update_fn gets a private copy: mutating the cached table directly would leave
  --- the cache holding changes that were never written if the write fails.
  function self.update(update_fn)
    local updated_data = update_fn(vim.deepcopy(self.read()))
    return self.write(updated_data)
  end

  return self
end

return M
