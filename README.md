# pile.nvim

![](https://img.shields.io/badge/license-MIT-blue.svg)

<div align="center">
  <img src="https://github.com/user-attachments/assets/7ad5a015-f188-45ea-870d-b37084d23934" width="300">
</div>

Display buffer vertically. It aims to be as easy to use as a stack of books.

## Overview

pile.nvim is a Neovim plugin that provides a vertical buffer sidebar, similar to how books are stacked in a pile. It offers an intuitive and simple way to browse, rename, and manage open buffers. Inspired by the user-friendly experience of oil.nvim, but designed for vertical organization.

## Features

- Vertical sidebar listing all open buffers.
- Easily switch between buffers with keyboard shortcuts.
- **Git worktree visual separation** - Automatically groups buffers by git worktree with visual separators.
- Editable buffer names within the sidebar for quick renaming.(not implemented yet)
- Automatically updates file names when a buffer is renamed.(not implemented yet)
- LSP integration: Automatically updates import paths when a file is renamed.(not implemented yet)

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
  -- Debug settings
  debug = {
    enabled = false,  -- Enable debug logging
    level = "info",   -- Log level: "error", "warn", "info", "debug", "trace"
  },

  -- Git worktree display settings
  worktree = {
    enabled = true,  -- Enable worktree visual separation
    separator = {
      enabled = true,      -- Show separator lines between worktrees
      style = "─",         -- Character to use for separator line
      show_branch = true,  -- Show branch/worktree name in separator
    },
    highlight = {
      separator = {
        fg = "#61AFEF",  -- Blue color for separator
        bold = true,
      },
      branch = {
        fg = "#98C379",  -- Green color for branch name
        bold = true,
      },
    },
  },
})
```

### Git Worktree Visual Separation

When working with multiple git worktrees, pile.nvim automatically detects and groups buffers by their associated worktree. Each worktree group is separated by a visual separator line that displays the branch name.

**Example sidebar with worktrees:**
```
─────── main ───────
config.lua
init.lua
──── feature/ui ────
component.lua
styles.lua
```

You can customize:
- `worktree.enabled` - Enable/disable worktree grouping
- `worktree.separator.enabled` - Show/hide separator lines
- `worktree.separator.style` - Character used for separator line
- `worktree.separator.show_branch` - Display branch name in separator
- `worktree.highlight.separator.fg` - Color of separator line
- `worktree.highlight.branch.fg` - Color of branch name

## Key Features:

1. Open Buffers: The sidebar shows all open buffers, with the current buffer highlighted.

## Usage

Open the sidebar:
:PileToggle
or set a keybind in your init.lua:

vim.api.nvim_set_keymap('n', '<leader>ps', ':PileToggle<CR>', { noremap = true, silent = true })

Navigate between buffers:
:PileGoToNextBuffer
:PileGoToPrevBuffer

Rename a buffer:
Edit the buffer name directly in the sidebar and save the changes to rename the file.

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

This project is licensed under the MIT License.


