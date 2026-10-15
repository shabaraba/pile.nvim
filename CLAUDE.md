# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pile.nvim is a Neovim plugin that provides a vertical buffer sidebar, displaying open buffers like stacked books. It uses nui.nvim for UI components.

## Development Commands

Since this is a Lua-based Neovim plugin, there is no build process. Testing is done by loading the plugin in Neovim:

```bash
# Test in Neovim (from plugin directory)
nvim --cmd "set rtp+=." -c "lua require('pile').setup()"
```

## Architecture

```
lua/pile/
├── init.lua           # Entry point - setup(), user commands, dependency check
├── config.lua         # Configuration management with defaults
├── globals.lua        # Shared state (sidebar_buf, sidebar_win)
├── log.lua            # Leveled logging (error/warn/info/debug/trace)
├── icons.lua          # File icon lookup (mini.icons / nvim-web-devicons)
├── buffers/
│   └── init.lua       # Buffer list management, duplicate path handling, navigation
├── windows/
│   ├── init.lua       # Window utilities (get_available_windows, set_buffer)
│   ├── sidebar/
│   │   ├── init.lua     # Sidebar lifecycle, debounced updates, autocmds
│   │   ├── render.lua   # Lines, current-buffer highlight, window indicators
│   │   └── keymaps.lua  # Sidebar keymaps (open, cut/yank/paste, reorder)
│   └── popup.lua      # Window selection popup using nui.nvim
└── repositories/
    └── sqlite.lua     # (placeholder/empty)
```

### Key Design Patterns

- **Shared State**: `globals.lua` holds sidebar window/buffer references used across modules
- **Duplicate File Handling**: `buffers/init.lua` implements smart path disambiguation when multiple files share the same name
- **Auto-updates**: `sidebar/init.lua` registers autocmds (BufAdd, BufEnter, BufLeave, FileType) to keep the sidebar in sync
- **oil.nvim Integration**: Buffer filtering excludes oil.nvim temporary buffers

### User Commands

- `:PileToggle` - Toggle sidebar visibility
- `:PileGoToNextBuffer` - Cycle to next buffer
- `:PileGoToPrevBuffer` - Cycle to previous buffer

### Sidebar Keymaps

- `<CR>` - Open buffer under cursor
- `dd` - Delete buffer under cursor
- `d` (visual) - Delete selected buffers

## Configuration

Debug logging can be enabled via setup:

```lua
require('pile').setup({
  debug = {
    enabled = true,
    level = "debug"  -- "error", "warn", "info", "debug", "trace"
  }
})
```

## Dependencies

- **Required**: nui.nvim (for popup UI)
- **Optional**: dressing.nvim (for enhanced vim.ui.select in popup.lua)

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
