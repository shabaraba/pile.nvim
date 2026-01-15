local log = require('pile.log')

local M = {}

local register = {}

local function store_buffers(buffers_to_store)
  register = {}
  for _, buffer in ipairs(buffers_to_store) do
    table.insert(register, {
      path = buffer.name,
      buf = buffer.buf
    })
  end
end

local function update_buffer_orders(buffer_list)
  for i, buf in ipairs(buffer_list) do
    buf.order = i - 1
  end
end

function M.cut(buffers)
  if not buffers or #buffers == 0 then
    log.debug("No buffers to cut")
    return false
  end

  -- Check for modified buffers and prompt user
  local modified_buffers = {}
  for _, buffer in ipairs(buffers) do
    if vim.api.nvim_buf_is_valid(buffer.buf) and vim.bo[buffer.buf].modified then
      table.insert(modified_buffers, buffer)
    end
  end

  if #modified_buffers > 0 then
    local names = {}
    for _, buf in ipairs(modified_buffers) do
      table.insert(names, buf.name)
    end
    local choice = vim.fn.confirm(
      string.format("Save changes to %d buffer(s)?\n%s", #modified_buffers, table.concat(names, "\n")),
      "&Save\n&Discard\n&Cancel",
      3
    )

    if choice == 1 then -- Save
      for _, buffer in ipairs(modified_buffers) do
        if vim.api.nvim_buf_is_valid(buffer.buf) then
          vim.api.nvim_buf_call(buffer.buf, function()
            vim.cmd('write')
          end)
        end
      end
    elseif choice == 3 then -- Cancel
      log.debug("Cut operation cancelled by user")
      return false
    end
    -- If choice == 2 (Discard), proceed with deletion
  end

  store_buffers(buffers)

  for _, buffer in ipairs(buffers) do
    if vim.api.nvim_buf_is_valid(buffer.buf) then
      vim.api.nvim_buf_delete(buffer.buf, { force = true })
    end
  end

  log.debug(string.format("Cut %d buffer(s)", #register))
  return true
end

function M.yank(buffers)
  if not buffers or #buffers == 0 then
    log.debug("No buffers to yank")
    return false
  end

  store_buffers(buffers)
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
    if buf > 0 then
      vim.fn.bufload(buf)
      table.insert(result, position + i, {
        buf = buf,
        name = item.path,
        filename = vim.fn.fnamemodify(item.path, ":t"),
        order = 0
      })
      pasted_count = pasted_count + 1
      log.trace("Pasted buffer: " .. item.path)
    end
  end

  update_buffer_orders(result)
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
