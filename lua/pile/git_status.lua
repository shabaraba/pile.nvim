local log = require('pile.log')

local M = {}

-- statuses[root][absolute path] = status letter
local statuses = {}
-- jobs[root] = "running" | "rerun"
local jobs = {}
local root_by_dir = {}

local function find_repo_root(path)
  local dir = vim.fs.dirname(path)
  if root_by_dir[dir] == nil then
    local git_dir = vim.fs.find('.git', { path = dir, upward = true })[1]
    root_by_dir[dir] = git_dir and vim.fs.dirname(git_dir) or false
  end
  return root_by_dir[dir] or nil
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

local function refresh_root(root, on_change)
  if jobs[root] then
    jobs[root] = "rerun"
    return
  end
  jobs[root] = "running"

  local output = {}
  vim.fn.jobstart({ 'git', '--no-optional-locks', '-C', root, 'status', '--porcelain=v1', '--untracked-files=all' }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      output = data or {}
    end,
    on_exit = function(_, code)
      if code == 0 then
        local result = parse_porcelain(root, output)
        if not vim.deep_equal(statuses[root], result) then
          statuses[root] = result
          vim.schedule(on_change)
        end
      else
        log.debug('git status failed in ' .. root)
      end

      -- A change made while git was running may be missing from this result
      local rerun = jobs[root] == "rerun"
      jobs[root] = nil
      if rerun then
        refresh_root(root, on_change)
      end
    end,
  })
end

--- Re-run `git status` for every repository that contains one of the paths
--- @param paths string[] Absolute buffer paths
--- @param on_change function Called when a repository's status differs from the stored one
function M.refresh(paths, on_change)
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
    refresh_root(root, on_change)
  end
end

--- @param path string Absolute buffer path
--- @return string|nil status One of "M", "A", "D", "R", "?", ...
function M.get(path)
  path = vim.fs.normalize(path)
  local root = find_repo_root(path)
  return root and statuses[root] and statuses[root][path]
end

return M
