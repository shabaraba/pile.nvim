local M = {}

function M.get_git_root(dir)
  local cwd = dir or vim.fn.getcwd()
  local cmd = string.format("cd %s && git rev-parse --show-toplevel 2>/dev/null", vim.fn.shellescape(cwd))
  local result = vim.fn.systemlist(cmd)

  if vim.v.shell_error == 0 and #result > 0 then
    return result[1]
  end

  return nil
end

function M.is_git_repo(dir)
  return M.get_git_root(dir) ~= nil
end

return M
