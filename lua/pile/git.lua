local log = require('pile.log')
local M = {}

-- Cache for worktree information
local worktree_cache = nil
local cache_timestamp = 0
local cache_ttl = 5000 -- 5 seconds TTL

-- Parse git worktree list output
local function parse_worktree_list(output)
  local worktrees = {}
  local current_worktree = nil

  for line in output:gmatch("[^\r\n]+") do
    -- Worktree path line starts with "worktree "
    if line:match("^worktree ") then
      local path = line:match("^worktree (.+)$")
      if path then
        current_worktree = {
          path = path,
          head = nil,
          branch = nil,
          bare = false
        }
        table.insert(worktrees, current_worktree)
      end
    elseif current_worktree then
      -- HEAD line
      local head = line:match("^HEAD (.+)$")
      if head then
        current_worktree.head = head
      end

      -- Branch line
      local branch = line:match("^branch refs/heads/(.+)$")
      if branch then
        current_worktree.branch = branch
      end

      -- Bare repo
      if line:match("^bare$") then
        current_worktree.bare = true
      end
    end
  end

  return worktrees
end

-- Get all git worktrees
function M.get_worktrees()
  local current_time = vim.loop.now()

  -- Return cached result if still valid
  if worktree_cache and (current_time - cache_timestamp) < cache_ttl then
    return worktree_cache
  end

  -- Execute git worktree list
  local output = vim.fn.system("git worktree list --porcelain 2>/dev/null")

  -- Check if git command succeeded
  if vim.v.shell_error ~= 0 then
    log.debug("git worktree list failed - not in a git repository or git not available")
    worktree_cache = {}
    cache_timestamp = current_time
    return {}
  end

  local worktrees = parse_worktree_list(output)

  -- Sort worktrees by path length (longer paths first) for proper matching
  table.sort(worktrees, function(a, b)
    return #a.path > #b.path
  end)

  log.debug(string.format("Found %d git worktrees", #worktrees))
  for i, wt in ipairs(worktrees) do
    log.debug(string.format("  [%d] path=%s, branch=%s, bare=%s",
                           i, wt.path, wt.branch or "detached", wt.bare))
  end

  worktree_cache = worktrees
  cache_timestamp = current_time

  return worktrees
end

-- Find which worktree a file belongs to
function M.get_worktree_for_file(filepath)
  if not filepath or filepath == "" then
    return nil
  end

  local worktrees = M.get_worktrees()

  -- No worktrees found
  if #worktrees == 0 then
    return nil
  end

  -- Normalize the filepath
  local normalized_path = vim.fn.fnamemodify(filepath, ":p")

  -- Find the worktree that contains this file
  -- We check longest paths first (already sorted)
  for _, worktree in ipairs(worktrees) do
    local wt_path = vim.fn.fnamemodify(worktree.path, ":p")

    -- Check if the file is under this worktree's path
    if normalized_path:sub(1, #wt_path) == wt_path then
      return worktree
    end
  end

  return nil
end

-- Get a display name for a worktree
function M.get_worktree_display_name(worktree)
  if not worktree then
    return "No Worktree"
  end

  if worktree.branch then
    return worktree.branch
  elseif worktree.head then
    -- Show shortened commit hash for detached HEAD
    return worktree.head:sub(1, 7)
  else
    -- Fallback to directory name
    return vim.fn.fnamemodify(worktree.path, ":t")
  end
end

-- Clear the worktree cache (useful for testing or manual refresh)
function M.clear_cache()
  worktree_cache = nil
  cache_timestamp = 0
end

return M
