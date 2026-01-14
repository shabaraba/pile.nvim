local log = require('pile.log')

local M = {}

local register = {}

function M.cut(buffers)
  if not buffers or #buffers == 0 then
    log.debug("No buffers to cut")
    return false
  end

  register = {}
  for _, buffer in ipairs(buffers) do
    table.insert(register, {
      path = buffer.name,
      buf = buffer.buf
    })
    vim.api.nvim_buf_delete(buffer.buf, { force = true })
  end

  log.debug(string.format("Cut %d buffer(s)", #register))
  return true
end

function M.yank(buffers)
  if not buffers or #buffers == 0 then
    log.debug("No buffers to yank")
    return false
  end

  register = {}
  for _, buffer in ipairs(buffers) do
    table.insert(register, {
      path = buffer.name,
      buf = buffer.buf
    })
  end

  log.debug(string.format("Yanked %d buffer(s)", #register))
  return true
end

function M.paste(position, buffer_list)
  if #register == 0 then
    log.debug("Register is empty")
    return buffer_list
  end

  local result = vim.deepcopy(buffer_list)
  local pasted_count = 0

  for i, item in ipairs(register) do
    local buf = vim.fn.bufadd(item.path)
    if buf and buf > 0 then
      vim.fn.bufload(buf)

      local insert_pos = position + i
      table.insert(result, insert_pos, {
        buf = buf,
        name = item.path,
        filename = vim.fn.fnamemodify(item.path, ":t"),
        order = 0
      })

      pasted_count = pasted_count + 1
      log.trace("Pasted buffer: " .. item.path)
    end
  end

  for i, buf in ipairs(result) do
    buf.order = i - 1
  end

  log.debug(string.format("Pasted %d buffer(s)", pasted_count))
  return result
end

function M.clear()
  register = {}
  log.debug("Register cleared")
end

function M.is_empty()
  return #register == 0
end

function M.get_count()
  return #register
end

return M
