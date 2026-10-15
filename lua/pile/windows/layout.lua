--- Split layout snapshots
--- Captures the current tab's split tree (vim.fn.winlayout) with each window's
--- position and size, and re-applies those sizes proportionally to a layout of
--- the same shape. Used to keep user split ratios across sidebar toggles and
--- to restore them from a saved session.
local M = {}

--- Capture the current tab's split tree
--- Excluded windows are dropped and their parent frames collapsed, the same way
--- Neovim would arrange the remaining windows.
--- @param exclude fun(win: number): boolean|nil Windows to leave out
--- @return table|nil Tree of {type='leaf', win, row, col, width, height} / {type='row'|'col', children}
function M.capture(exclude)
  local function build(node)
    local kind, data = node[1], node[2]
    if kind == 'leaf' then
      if exclude and exclude(data) then
        return nil
      end
      local pos = vim.api.nvim_win_get_position(data)
      return {
        type = 'leaf',
        win = data,
        row = pos[1],
        col = pos[2],
        width = vim.api.nvim_win_get_width(data),
        height = vim.api.nvim_win_get_height(data),
      }
    end

    local children = {}
    for _, child in ipairs(data) do
      local built = build(child)
      if built then
        table.insert(children, built)
      end
    end
    return M.normalize({ type = kind, children = children })
  end

  return build(vim.fn.winlayout())
end

--- Collapse single-child frames and merge nested frames of the same direction
--- Neovim never nests a row directly in a row, so a pruned tree must be
--- flattened before its shape can be compared with a real layout.
--- @param node table Frame node whose children are already normalized
--- @return table|nil
function M.normalize(node)
  if node.type == 'leaf' then
    return node
  end

  local children = {}
  for _, child in ipairs(node.children) do
    if child.type == node.type then
      vim.list_extend(children, child.children)
    else
      table.insert(children, child)
    end
  end

  if #children == 0 then
    return nil
  elseif #children == 1 then
    return children[1]
  end
  return { type = node.type, children = children }
end

--- @return table[] Leaves in depth-first order
function M.leaves(node, out)
  out = out or {}
  if node.type == 'leaf' then
    table.insert(out, node)
  else
    for _, child in ipairs(node.children) do
      M.leaves(child, out)
    end
  end
  return out
end

--- @return boolean True if both trees have the same frame structure
function M.same_shape(a, b)
  if not a or not b or a.type ~= b.type then
    return false
  end
  if a.type == 'leaf' then
    return true
  end
  if #a.children ~= #b.children then
    return false
  end
  for i = 1, #a.children do
    if not M.same_shape(a.children[i], b.children[i]) then
      return false
    end
  end
  return true
end

local DIMS = {
  width = { pos = 'col', along = 'row', fix = 'winfixwidth' },
  height = { pos = 'row', along = 'col', fix = 'winfixheight' },
}

--- Screen cells a frame spans in one dimension, separators included
--- Derived from leaf positions so it is exact whatever 'laststatus' is.
local function extent(node, dim)
  local d = DIMS[dim]
  local first, last
  for _, leaf in ipairs(M.leaves(node)) do
    local start = leaf[d.pos]
    local stop = start + leaf[dim]
    first = first and math.min(first, start) or start
    last = last and math.max(last, stop) or stop
  end
  return last - first
end

--- Compute target sizes for the leaves of `cur` from the proportions of `old`
--- @param old table Source tree (proportions)
--- @param cur table Current tree of the same shape (real windows, overhead)
--- @param size number Cells available to this frame
--- @param targets table<number, table> win -> {width, height}
local function assign(old, cur, dim, size, targets)
  if cur.type == 'leaf' then
    targets[cur.win] = targets[cur.win] or {}
    targets[cur.win][dim] = size
    return
  end

  if cur.type ~= DIMS[dim].along then
    for i, child in ipairs(cur.children) do
      assign(old.children[i], child, dim, size, targets)
    end
    return
  end

  -- Separators/statuslines between children are not distributable space
  local overhead = extent(cur, dim)
  for _, child in ipairs(cur.children) do
    overhead = overhead - extent(child, dim)
  end
  local available = size - overhead

  -- Windows with winfixwidth/winfixheight keep their size; the rest share what is left
  local sizes, fixed = {}, {}
  local flexible_old, remaining = 0, available
  for i, child in ipairs(cur.children) do
    if child.type == 'leaf' and vim.wo[child.win][DIMS[dim].fix] then
      fixed[i] = true
      sizes[i] = extent(child, dim)
      remaining = remaining - sizes[i]
    else
      flexible_old = flexible_old + extent(old.children[i], dim)
    end
  end

  local used, last_flexible = 0, nil
  for i in ipairs(cur.children) do
    if not fixed[i] then
      local share = flexible_old > 0
        and extent(old.children[i], dim) / flexible_old
        or 1 / #cur.children
      sizes[i] = math.max(1, math.floor(remaining * share + 0.5))
      last_flexible = i
    end
    used = used + sizes[i]
  end
  -- Rounding leftovers go to the last flexible child so the frame stays full
  local last = last_flexible or #cur.children
  sizes[last] = math.max(1, sizes[last] + available - used)

  for i, child in ipairs(cur.children) do
    assign(old.children[i], child, dim, sizes[i], targets)
  end
end

--- Resize the windows of `cur` so they take the proportions recorded in `old`
--- @param old table Tree to take proportions from (from capture or a saved session)
--- @param cur table|nil Tree of the windows to resize; defaults to capture()
--- @return boolean True if the layouts matched and sizes were applied
function M.apply(old, cur, exclude)
  cur = cur or M.capture(exclude)
  if not M.same_shape(old, cur) then
    return false
  end

  local targets = {}
  for dim in pairs(DIMS) do
    assign(old, cur, dim, extent(cur, dim), targets)
  end

  -- Resizing one window shifts its neighbours; a second pass settles nested frames
  local leaves = M.leaves(cur)
  for _ = 1, 2 do
    for _, leaf in ipairs(leaves) do
      local target = targets[leaf.win]
      if target and vim.api.nvim_win_is_valid(leaf.win) then
        pcall(vim.api.nvim_win_set_width, leaf.win, target.width)
        pcall(vim.api.nvim_win_set_height, leaf.win, target.height)
      end
    end
  end
  return true
end

--- Run fn with 'equalalways' off so opening/closing a window leaves the others alone
--- Turning 'equalalways' back on equalizes all windows, so callers re-apply
--- their sizes after this returns.
function M.without_equalalways(fn)
  local saved = vim.o.equalalways
  vim.o.equalalways = false
  local ok, err = pcall(fn)
  vim.o.equalalways = saved
  if not ok then
    error(err, 0)
  end
end

return M
