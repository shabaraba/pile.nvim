local log = require('pile.log')

local M = {}

function M.new(config)
  local self = {
    filepath = config.filepath,
    default_data = config.default_data or {},
  }

  local function ensure_directory()
    local dir = vim.fn.fnamemodify(self.filepath, ':h')
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, 'p')
      log.debug("Created directory: " .. dir)
    end
  end

  function self.read()
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
    return data
  end

  function self.write(data)
    ensure_directory()

    local ok, json_string = pcall(vim.fn.json_encode, data)
    if not ok then
      log.error("Failed to encode JSON: " .. self.filepath)
      return false
    end

    local file = io.open(self.filepath, 'w')
    if not file then
      log.error("Failed to open file for writing: " .. self.filepath)
      return false
    end

    file:write(json_string)
    file:close()

    log.trace("Wrote data to: " .. self.filepath)
    return true
  end

  function self.update(update_fn)
    local data = self.read()
    local updated_data = update_fn(data)
    return self.write(updated_data)
  end

  return self
end

return M
