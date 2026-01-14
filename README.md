# pile.nvim

![](https://img.shields.io/badge/license-MIT-blue.svg)

<div align="center">
  <img src="https://github.com/user-attachments/assets/7ad5a015-f188-45ea-870d-b37084d23934" width="300">
</div>

Display buffer vertically. It aims to be as easy to use as a stack of books.

## Overview

pile.nvim is a Neovim plugin that provides a vertical buffer sidebar, similar to how books are stacked in a pile. It offers an intuitive and simple way to browse, rename, and manage open buffers. Inspired by the user-friendly experience of oil.nvim, but designed for vertical organization.

## Features

- ✅ Vertical sidebar listing all open buffers
- ✅ Easily switch between buffers with keyboard shortcuts
- ✅ Buffer access history tracking (persistent across sessions)
- ✅ Multiple sort modes: MRU (Most Recently Used), frequency, score-based
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
  -- History management
  history = {
    enabled = true,           -- Enable history tracking
    auto_cleanup_days = 30,   -- Auto-remove entries older than N days
  },

  -- Sort settings
  sort = {
    method = "buffer_number", -- "buffer_number", "mru", "frequency", "score"
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

### History Management Commands

```vim
:PileSetSortMode <mode>  " Set sort mode: buffer_number, mru, frequency, score
:PileHistoryStats        " Show history statistics
:PileHistoryClear        " Clear all history data
```

### Keybindings

Set up convenient keybindings in your `init.lua`:

```lua
vim.api.nvim_set_keymap('n', '<leader>ps', ':PileToggle<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>pn', ':PileGoToNextBuffer<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>pp', ':PileGoToPrevBuffer<CR>', { noremap = true, silent = true })
```

### Sidebar Keybindings

While in the sidebar:
- `<CR>`: Open the selected buffer
- `dd`: Delete the buffer under cursor
- `d` (visual mode): Delete multiple buffers

### Sort Modes

- **buffer_number**: Default Neovim buffer order
- **mru**: Most Recently Used - recently accessed buffers first
- **frequency**: Most frequently accessed buffers first
- **score**: Combined score based on recency (70%) and frequency (30%)

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

This project is licensed under the MIT License.


