local config = require 'pile.config'
local git_status = require 'pile.git_status'

local M = {}

local GIT_HIGHLIGHTS = {
  ['?'] = "PileGitUntracked",
  A = "PileGitAdded",
  D = "PileGitDeleted",
}

--- Build the right-aligned status marks (unsaved changes, git status) for a line
--- @param buffer table Entry from buffers.get_list()
--- @return table virt_text
function M.build(buffer)
  local virt_text = {}

  if config.marks.git and buffer.name ~= "" then
    local status = git_status.get(buffer.name)
    if status then
      table.insert(virt_text, {status, GIT_HIGHLIGHTS[status] or "PileGitModified"})
    end
  end

  if config.marks.modified and vim.api.nvim_buf_is_valid(buffer.buf) and vim.bo[buffer.buf].modified then
    if #virt_text > 0 then
      table.insert(virt_text, {" ", "Normal"})
    end
    table.insert(virt_text, {"\226\151\143", "PileModified"})
  end

  return virt_text
end

return M
