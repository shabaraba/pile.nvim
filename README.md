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
- Editable buffer names within the sidebar for quick renaming.(not implemented yet)
- Automatically updates file names when a buffer is renamed.(not implemented yet)
- LSP integration: Automatically updates import paths when a file is renamed.(not implemented yet)


## Installation

Using Lazy.nvim:
```lua
{
  'shabaraba/pile.nvim',
  opts ={}
}
```

## Setup and Configuration

<!--

To configure pile.nvim, add the following setup function to your Neovim config.

```lua
require('pile').setup({
  -- Configuration options
  width = 30,              -- Width of the sidebar
  highlight_current = true, -- Highlight the current buffer in the sidebar
  keymaps = {
    open_buffer = '<CR>',   -- Keymap to open the buffer
    close_sidebar = 'q',    -- Keymap to close the sidebar
  },
})
```

-->

## Key Features:

1. Open Buffers: The sidebar shows all open buffers, with the current buffer highlighted.



## Usage

Open the sidebar:
:PileOpen
or set a keybind in your init.lua:

vim.api.nvim_set_keymap('n', '<leader>ps', ':PileOpen<CR>', { noremap = true, silent = true })

Close the sidebar:
:PileClose

Rename a buffer:
Edit the buffer name directly in the sidebar and save the changes to rename the file.


## Requirements

Neovim 0.5 or later

LSP configuration for full renaming functionality


## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

This project is licensed under the MIT License.


