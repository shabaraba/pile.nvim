-- Commands are defined at startup; the rest of pile.nvim loads when one is used
-- or when Neovim has finished starting (to run the session auto-save/restore).
if vim.g.loaded_pile then
  return
end
vim.g.loaded_pile = true

if vim.fn.has("nvim-0.10") == 0 then
  vim.notify("pile.nvim requires Neovim 0.10 or later", vim.log.levels.ERROR)
  return
end

local function call(name)
  return function(opts)
    require("pile")[name](opts)
  end
end

local function complete_sessions()
  return require("pile.features.session").list_sessions()
end

local commands = {
  PileToggle = { call("toggle_sidebar"), { desc = "toggle pile window" } },
  PileGoToNextBuffer = { call("switch_to_next_buffer"), { desc = "go to next buffer" } },
  PileGoToPrevBuffer = { call("switch_to_prev_buffer"), { desc = "go to prev buffer" } },
  PileSaveSession = { call("save_session"), { nargs = "?", desc = "save current buffers to session" } },
  PileRestoreSession = {
    call("restore_session"),
    { nargs = "?", complete = complete_sessions, desc = "restore session" },
  },
  PileCreateSession = { call("create_session"), { nargs = 1, desc = "create new session with name" } },
  PileSwitchSession = {
    call("switch_session"),
    { nargs = 1, complete = complete_sessions, desc = "switch to session" },
  },
  PileDeleteSession = {
    call("delete_session"),
    { nargs = 1, complete = complete_sessions, desc = "delete session" },
  },
  PileListSessions = { call("list_sessions"), { desc = "list all sessions" } },
  PilePruneAliases = {
    call("prune_aliases"),
    { desc = "remove display names of files that no longer exist" },
  },
  PileMoveBufferUp = { call("move_buffer_up"), { desc = "move current buffer up in sidebar" } },
  PileMoveBufferDown = { call("move_buffer_down"), { desc = "move current buffer down in sidebar" } },
  PileSort = {
    call("sort_buffers"),
    {
      nargs = 1,
      bang = true,
      complete = function()
        return require("pile.features.sort").KEYS
      end,
      desc = "sort buffers in sidebar (! to reverse)",
    },
  },
}

for name, def in pairs(commands) do
  vim.api.nvim_create_user_command(name, def[1], def[2])
end

-- Initialize with vim.g.pile unless the user calls setup() first. Plugin managers
-- run the user's setup() right after sourcing this file, so wait until then.
local function auto_initialize()
  require("pile").ensure_initialized()
end

if vim.v.vim_did_enter == 1 then
  vim.schedule(auto_initialize)
else
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = auto_initialize,
  })
end
