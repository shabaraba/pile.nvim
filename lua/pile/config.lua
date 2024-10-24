-- setupで受け取るconfigはここ
local M = {}

M.setup = function(opts)
  -- M.sidebar = {
  --   width = opts.sidebar.width,
  --   position = opts.sidebar.position,
  --   transparent = opts.sidebar.transparent,
  -- }
  -- M.functions = {
  --   manage_multiple_buffer_lists = opts.functions.manage_multiple_buffer_lists,
  -- }
  M.buffer = {
    highlight = {
      current = {
        bg = "#3E4452",
        fg = "Red",

        -- bg = (opts.buffer.highlight.current.bg ~= nil) and opts.buffer.highlight.current.bg or "#3E4452",
        -- fg = (opts.buffer.highlight.current.fg ~= nil) and opts.buffer.highlight.current.fg or "Red",
      },
      -- selected = {
      --   bg = opts.buffer.highlight.selected.bg,
      --   fg = opts.buffer.highlight.selected.fg,
      -- }
    },
    -- sort = opts.buffer.sort,
    -- ascending = opts.buffer.ascending,
  }
end

return M
