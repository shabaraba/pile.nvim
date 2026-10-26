local M = {
  debug = {
    enabled = false,
    level = "info",
  }
}

M.setup = function(opts)
  opts = opts or {}

  local function set_default(path, default_value)
    local table_path = opts
    local levels = {}
    for part in string.gmatch(path, "[^.]+") do
      table.insert(levels, part)
    end

    for i = 1, #levels - 1 do
      local key = levels[i]
      if table_path[key] == nil then
        table_path[key] = {}
      end
      table_path = table_path[key]
    end

    local final_key = levels[#levels]
    if table_path[final_key] == nil then
      table_path[final_key] = default_value
    end

    return table_path[final_key]
  end

  if opts.debug then
    M.debug.enabled = opts.debug.enabled or M.debug.enabled
    M.debug.level = opts.debug.level or M.debug.level
  end

  M.buffer = {
    highlight = {
      current = { bg = "#3E4452", fg = "Red" },
    },
  }

  M.window_indicator = {
    enabled = set_default("window_indicator.enabled", true),
    style = set_default("window_indicator.style", "block"),
    colors = set_default("window_indicator.colors", {
      "#E06C75", "#98C379", "#E5C07B", "#61AFEF", "#C678DD",
      "#56B6C2", "#D19A66", "#ABB2BF", "#E06C75", "#98C379",
    }),
  }

  M.icons = {
    enabled = set_default("icons.enabled", true),
    position = set_default("icons.position", "left"),
  }

  M.marks = {
    modified = set_default("marks.modified", true),
    git = set_default("marks.git", true),
  }

  M.preview = {
    auto_open = set_default("preview.auto_open", false),
    border = set_default("preview.border", "rounded"),
  }

  M.rename = {
    confirm = set_default("rename.confirm", true),
  }

  M.tabline = {
    enabled = set_default("tabline.enabled", false),
  }

  M.tab_separator = {
    enabled = set_default("tab_separator.enabled", true),
    char = set_default("tab_separator.char", "─"),
  }

  M.window_picker = set_default("window_picker", {})

  for _, rule in ipairs({ "exclude", "include" }) do
    M[rule] = {
      filenames = set_default(rule .. ".filenames", {}),
      filetypes = set_default(rule .. ".filetypes", {}),
      buftypes = set_default(rule .. ".buftypes", {}),
    }
  end

  M.session = {
    auto_save = set_default("session.auto_save", true),
    auto_restore = set_default("session.auto_restore", true),
    preserve_order = set_default("session.preserve_order", true),
  }
end

return M
