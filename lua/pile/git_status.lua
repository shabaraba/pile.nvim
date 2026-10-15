local log = require('pile.log')

local M = {}

local statuses = {}
local running = {}
local rerun = {}

local function find_repo_root(path)
  local git_dir = vim.fs.find('.git', { path = vim.fs.dirname(path), upward = true })[1]
  return git_dir and vim.fs.dirname(git_dir) or nil
end

local function unquote(path)
  return path:match('^"(.*)"$') or path
end

--- Reduce a porcelain XY code to one letter, preferring the worktree side
local function to_status(xy)
  if xy == '??' then
    return '?'
  end
  local worktree = xy:sub(2, 2)
  if worktree ~= ' ' then
    return worktree
  end
  return xy:sub(1, 1)
end

local function parse_porcelain(root, lines)
  local result = {}
  for _, line in ipairs(lines) do
    if #line > 3 then
      local path = line:sub(4)
      path = path:match(' %-> (.+)$') or path
      result[root .. '/' .. unquote(path)] = to_status(line:sub(1, 2))
    end
  end
  return result
end

local function refresh_root(root, on_done)
  if running[root] then
    rerun[root] = true
    return
  end
  running[root] = true

  vim.fn.jobstart({ 'git', '-C', root, 'status', '--porcelain=v1', '--untracked-files=all' }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for path in pairs(statuses) do
        if vim.startswith(path, root .. '/') then
          statuses[path] = nil
        end
      end
      for path, status in pairs(parse_porcelain(root, data or {})) do
        statuses[path] = status
      end
    end,
    on_exit = function(_, code)
      running[root] = nil
      if code ~= 0 then
        log.debug('git status failed in ' .. root)
      end
      vim.schedule(on_done)
      -- A change made while git was running may be missing from this result
      if rerun[root] then
        rerun[root] = nil
        refresh_root(root, on_done)
      end
    end,
  })
end

--- Re-run `git status` for every repository that contains one of the paths
--- @param paths string[] Absolute buffer paths
--- @param on_done function Called once per repository after its status is stored
function M.refresh(paths, on_done)
  local roots = {}
  for _, path in ipairs(paths) do
    if path ~= '' then
      local root = find_repo_root(path)
      if root then
        roots[root] = true
      end
    end
  end
  for root in pairs(roots) do
    refresh_root(root, on_done)
  end
end

--- @param path string Absolute buffer path
--- @return string|nil status One of "M", "A", "D", "R", "?", ...
function M.get(path)
  return statuses[vim.fs.normalize(path)]
end

return M
