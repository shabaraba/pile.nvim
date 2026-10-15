local globals = require 'pile.globals'
local config = require 'pile.config'
local git_status = require 'pile.git_status'

local M = {}

local sidebar = nil
local known_modified = {}

local function git_marks_active()
  return sidebar and sidebar.is_opened() and not sidebar._suspended and config.marks.git
end

local function on_git_change()
  sidebar.schedule_update()
end

--- Re-read git status for the listed buffers and redraw when it changes
function M.refresh_git()
  if not git_marks_active() then
    return
  end

  local paths = {}
  for _, buffer in ipairs(sidebar.get_buffer_list()) do
    table.insert(paths, buffer.name)
  end
  git_status.refresh(paths, on_git_change)
end

--- @param sidebar_module table Sidebar module providing is_opened(), get_buffer_list() and schedule_update()
function M.setup(sidebar_module)
  sidebar = sidebar_module

  -- Neovim has no BufModifiedSet, so watch the events that can flip 'modified'
  -- and redraw only when the flag actually changes.
  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI", "TextChangedP", "BufWritePost", "BufReadPost"}, {
    pattern = "*",
    callback = function(ev)
      -- config.marks is unset until setup() succeeds
      if not (config.marks and config.marks.modified) or ev.buf == globals.sidebar_buf or not vim.api.nvim_buf_is_valid(ev.buf) then
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

  vim.api.nvim_create_autocmd({"BufReadPost", "BufWritePost"}, {
    pattern = "*",
    callback = function(ev)
      if git_marks_active() then
        git_status.refresh({ vim.api.nvim_buf_get_name(ev.buf) }, on_git_change)
      end
    end,
  })

  vim.api.nvim_create_autocmd({"FocusGained", "ShellCmdPost", "TermLeave"}, {
    pattern = "*",
    callback = M.refresh_git,
  })
end

return M
