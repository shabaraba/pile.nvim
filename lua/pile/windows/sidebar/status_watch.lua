local globals = require 'pile.globals'
local buffers = require 'pile.buffers'
local config = require 'pile.config'
local git_status = require 'pile.git_status'

local M = {}

local sidebar = nil
local known_modified = {}

--- Re-read git status for the listed buffers and redraw when it arrives
function M.refresh_git()
  if not sidebar or not (config.marks and config.marks.git) or not sidebar.is_opened() or sidebar._suspended then
    return
  end

  local paths = {}
  for _, buffer in ipairs(buffers.get_list()) do
    table.insert(paths, buffer.name)
  end
  git_status.refresh(paths, function()
    sidebar.schedule_update()
  end)
end

--- @param sidebar_module table Sidebar module providing is_opened() and schedule_update()
function M.setup(sidebar_module)
  sidebar = sidebar_module

  -- Neovim has no BufModifiedSet, so watch the events that can flip 'modified'
  -- and redraw only when the flag actually changes.
  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI", "TextChangedP", "BufWritePost", "BufReadPost"}, {
    pattern = "*",
    callback = function(ev)
      if ev.buf == globals.sidebar_buf or not vim.api.nvim_buf_is_valid(ev.buf) then
        return
      end
      local modified = vim.bo[ev.buf].modified
      if known_modified[ev.buf] ~= modified then
        known_modified[ev.buf] = modified
        sidebar.schedule_update()
      end
    end
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    pattern = "*",
    callback = function(ev)
      known_modified[ev.buf] = nil
    end
  })

  vim.api.nvim_create_autocmd({"BufReadPost", "BufWritePost", "FocusGained", "ShellCmdPost", "TermLeave"}, {
    pattern = "*",
    callback = function()
      M.refresh_git()
    end,
  })
end

return M
