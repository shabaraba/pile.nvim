# pile.nvim

![](https://img.shields.io/badge/license-MIT-blue.svg)

<div align="center">
  <img src="https://github.com/user-attachments/assets/7ad5a015-f188-45ea-870d-b37084d23934" width="300">
</div>

Display buffer vertically. It aims to be as easy to use as a stack of books.

## Overview

pile.nvim is a Neovim plugin that provides a vertical buffer sidebar, similar to how books are stacked in a pile. It offers an intuitive and simple way to browse, rename, and manage open buffers. Inspired by the user-friendly experience of oil.nvim, but designed for vertical organization.

## Features

- ✅ **Session Management**: Auto-restore previous buffers on startup
- ✅ **Named Sessions**: Save and switch between different buffer sets
- ✅ **Custom Buffer Order**: Freely reorder buffers and persist the order
- ✅ Vertical sidebar listing all open buffers
- ✅ Easily switch between buffers with keyboard shortcuts
- ✅ Smart duplicate filename resolution
- ✅ Visual window indicators
- 🚧 Editable buffer names within the sidebar for quick renaming (not implemented yet)
- 🚧 Automatically updates file names when a buffer is renamed (not implemented yet)
- 🚧 LSP integration: Automatically updates import paths when a file is renamed (not implemented yet)

## Requirements

- Neovim 0.5 or later
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) - Required for UI components
- LSP configuration for full renaming functionality (optional)

## Installation

### Using [Lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'shabaraba/pile.nvim',
  dependencies = {
    'MunifTanjim/nui.nvim', -- Required dependency
  },
  opts = {}
}
```

### Using [Packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'shabaraba/pile.nvim',
  requires = { 'MunifTanjim/nui.nvim' }, -- Required dependency
  config = function()
    require('pile').setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'MunifTanjim/nui.nvim'  " Required dependency
Plug 'shabaraba/pile.nvim'
```

## Setup and Configuration

To configure pile.nvim, add the following setup function to your Neovim config:

```lua
require('pile').setup({
  -- Session management
  session = {
    auto_save = true,         -- Auto-save session on exit
    auto_restore = true,      -- Auto-restore session on startup
    preserve_order = true,    -- Preserve buffer order
  },

  -- Window indicator
  window_indicator = {
    enabled = true,           -- Show window indicators
    colors = {                -- Color palette for indicators
      "#E06C75", "#98C379", "#E5C07B", "#61AFEF",
      "#C678DD", "#56B6C2", "#D19A66", "#ABB2BF",
    },
  },

  -- Debug settings
  debug = {
    enabled = false,
    level = "info",           -- "error", "warn", "info", "debug", "trace"
  },
})
```

## Key Features:

1. Open Buffers: The sidebar shows all open buffers, with the current buffer highlighted.

## Usage

### Basic Commands

```vim
:PileToggle              " Toggle the sidebar
:PileGoToNextBuffer      " Switch to next buffer
:PileGoToPrevBuffer      " Switch to previous buffer
```

### Session Management Commands

```vim
:PileSaveSession [name]          " Save current buffers to session
:PileRestoreSession [name]       " Restore session
:PileCreateSession <name>        " Create new named session
:PileSwitchSession <name>        " Switch to another session
:PileDeleteSession <name>        " Delete a session
:PileListSessions                " List all sessions
```

### Buffer Reordering Commands

```vim
:PileMoveBufferUp                " Move current buffer up in sidebar
:PileMoveBufferDown              " Move current buffer down in sidebar
```

### Keybindings

Set up convenient keybindings in your `init.lua`:

```lua
-- Basic operations
vim.api.nvim_set_keymap('n', '<leader>ps', ':PileToggle<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>pn', ':PileGoToNextBuffer<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>pp', ':PileGoToPrevBuffer<CR>', { noremap = true, silent = true })

-- Session management
vim.api.nvim_set_keymap('n', '<leader>pss', ':PileSaveSession<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>psr', ':PileRestoreSession<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>psl', ':PileListSessions<CR>', { noremap = true, silent = true })

-- Buffer reordering
vim.api.nvim_set_keymap('n', '<leader>pmu', ':PileMoveBufferUp<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>pmd', ':PileMoveBufferDown<CR>', { noremap = true, silent = true })
```

### Sidebar Keybindings

While in the sidebar:
- `<CR>`: Open the selected buffer
- `q` / `<Esc>`: Close sidebar

**Buffer Operations (Vim-like):**
- `dd`: Cut buffer (delete + save to register)
- `yy`: Yank buffer (copy to register without deleting)
- `p`: Paste buffers below cursor
- `P`: Paste buffers above cursor
- `D`: Delete buffer immediately (without saving to register)
- `d` (visual mode): Cut multiple selected buffers
- `y` (visual mode): Yank multiple selected buffers

**Buffer Reordering:**
- **Normal mode:**
  - `<C-j>`: Move current buffer down
  - `<C-k>`: Move current buffer up
- **Visual mode:**
  - `V` or `Shift+V`: Select line (start visual line mode)
  - `j`/`k`: Extend selection
  - `<C-j>`: Move selected buffers down
  - `<C-k>`: Move selected buffers up

**Note:** The register is automatically cleared when you leave the sidebar window.

### How Sessions Work

- **Auto-save**: When you exit Neovim, current buffers are saved to the "default" session
- **Auto-restore**: On startup, buffers from the last session are automatically restored
- **Named sessions**: Create multiple sessions for different projects or workflows
- **Buffer order**: Your custom buffer order is preserved across sessions

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

This project is licensed under the MIT License.


