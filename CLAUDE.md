# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pile.nvim is a Neovim plugin (Neovim 0.10+) that provides a vertical buffer sidebar, displaying open buffers like stacked books. Buffers can be reordered, aliased and renamed by editing the sidebar, and the order is persisted per project as sessions.

## Development Commands

Since this is a Lua-based Neovim plugin, there is no build process. Testing is done by loading the plugin in Neovim (nvim-window-picker must be on the runtimepath):

```bash
# Test in Neovim (from plugin directory); setup() is optional
nvim --cmd "set rtp+=." --cmd "set rtp+=/path/to/nvim-window-picker"

# Check the environment and options
nvim --cmd "set rtp+=." +"checkhealth pile"
```

## Architecture

```
plugin/
└── pile.lua           # Defines user commands; auto-initializes on VimEnter (setup() optional)
doc/
└── pile.txt           # Vimdoc (:help pile)
handbook/              # Detailed user documentation (Markdown)
lua/pile/
├── init.lua           # setup()/ensure_initialized(), highlights, autocmds, command handlers
├── health.lua         # :checkhealth pile
├── config.lua         # Configuration management with defaults
├── globals.lua        # Shared state (sidebar_buf, sidebar_win)
├── log.lua            # Leveled logging (error/warn/info/debug/trace)
├── icons.lua          # File icon lookup (mini.icons / nvim-web-devicons)
├── git_status.lua     # Async `git status --porcelain` cache per repository
├── window_colors.lua  # Color assignment for window indicators
├── buffers/
│   ├── init.lua       # Buffer list, aliases, open in window, next/prev navigation
│   ├── filter.lua     # Listed/unlisted filtering, exclude/include rules
│   └── disambiguate.lua # Path prefixes for buffers sharing a file name
├── features/
│   ├── aliases.lua    # Aliases follow buffer renames; :PilePruneAliases
│   ├── session.lua    # Save/restore buffers and window layout
│   ├── reorder.lua    # Persisted custom buffer order
│   ├── register.lua   # Sidebar cut/yank/paste register
│   ├── sort.lua       # :PileSort keys
│   └── file_rename.lua # Rename files on disk + LSP willRenameFiles/didRenameFiles
├── storage/
│   ├── json_store.lua   # Cached, atomically written JSON file
│   └── session_store.lua # Per-project sessions and aliases (stdpath('data')/pile)
├── utils/
│   └── git.lua        # git root lookup
└── windows/
    ├── init.lua       # Window utilities (get_available_windows, set_buffer)
    ├── layout.lua     # Split-tree snapshots; re-applies split ratios after toggle/restore
    ├── picker.lua     # nvim-window-picker integration
    ├── preview.lua    # Floating preview that follows the sidebar cursor
    └── sidebar/
        ├── init.lua     # Sidebar lifecycle, debounced updates, autocmds
        ├── render.lua   # Lines, current-buffer highlight, window indicators
        ├── keymaps.lua  # Sidebar keymaps (open, cut/yank/paste, reorder)
        ├── marks.lua    # Right-aligned unsaved/git status marks
        ├── status_watch.lua # Autocmds that refresh modified/git state
        └── edit_mode.lua  # Editable sidebar for aliases (a) and file renames (e)
```

### Key Design Patterns

- **Optional setup**: `plugin/pile.lua` defines commands and calls `require('pile').ensure_initialized()` on VimEnter. `setup(opts)` merges `opts` over `vim.g.pile` and is idempotent (augroup `Pile` is cleared); public functions in `init.lua` auto-initialize
- **Shared State**: `globals.lua` holds sidebar window/buffer references used across modules
- **Duplicate File Handling**: `buffers/disambiguate.lua` prefixes the shortest distinguishing directory
- **Auto-updates**: `sidebar/init.lua` registers autocmds (BufAdd, BufEnter, BufLeave, FileType) and debounces redraws
- **oil.nvim Integration**: Buffer filtering excludes oil.nvim buffers

### User Commands

- `:PileToggle`, `:PileGoToNextBuffer`, `:PileGoToPrevBuffer`
- `:PileMoveBufferUp`, `:PileMoveBufferDown`, `:PileSort[!] {key}`
- `:PileSaveSession`, `:PileRestoreSession`, `:PileCreateSession`, `:PileSwitchSession`, `:PileDeleteSession`, `:PileListSessions`
- `:PilePruneAliases`

### Sidebar Keymaps

- `<CR>` open, `K` preview, `dd`/`yy`/`p`/`P` register (visual `d`/`y`), `D` wipe buffer
- `<C-j>`/`<C-k>` reorder (normal and visual)
- `a` edit aliases, `e` edit file paths (`:w` applies, `q` cancels)

## Configuration

Debug logging can be enabled via setup (or `vim.g.pile`):

```lua
require('pile').setup({
  debug = {
    enabled = true,
    level = "debug"  -- "error", "warn", "info", "debug", "trace"
  }
})
```

## Dependencies

- **Required**: s1n7ax/nvim-window-picker (choosing the target window)
- **Optional**: mini.icons or nvim-web-devicons (icons), git (status marks, per-project sessions)

## Documentation

User-facing behavior is documented in three places; update all that apply when behavior changes:

- `README.md` — overview, install, defaults, command/keymap tables
- `handbook/*.md` — detailed behavior
- `doc/pile.txt` — vimdoc (`:helptags doc` must succeed; keep lines ≤ 78 chars)

## Development Workflow

Per `.github/copilot-instructions.md`:

- GitHub owner: `shabaraba`
- Tasks managed via GitHub Issues
- Debug output: pipe to `.github/working/output.log`, then delete after inspection
- Commit messages: Semantic Commit Messages in English (feat/fix/chore/test/refactor)
- PR titles: Semantic Commit Messages style
- PR body: Japanese

### Custom Command Prefixes

- `:input` - Read and understand content, do not implement
- `:research` - Research task using web/sources, no implementation
- `:invest` - Investigate existing code, plan, test code only
- `:impl` - Implement with branch, tests, build verification
- `:refactor` - Redesign without breaking existing functionality
