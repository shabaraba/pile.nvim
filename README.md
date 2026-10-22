# pile.nvim

![](https://img.shields.io/badge/license-MIT-blue.svg)
![](https://img.shields.io/badge/Neovim-0.10%2B-green.svg)

<div align="center">
  <img src="https://github.com/user-attachments/assets/7ad5a015-f188-45ea-870d-b37084d23934" width="300">
</div>

A vertical buffer sidebar for Neovim — your open buffers, stacked like a pile of books.

pile.nvim lists your buffers in a sidebar that you edit like a normal buffer: reorder them with
`dd` / `p`, give them display names, or rename the files on disk with `:w`, in the spirit of
[oil.nvim](https://github.com/stevearc/oil.nvim). The order you choose is remembered per project.

## ✨ Features

- **Buffer sidebar** — lists the same buffers as `:ls`, highlights the current one, and opens a
  buffer in the window you pick
- **Grouped by tab** — buffers are listed under the tab they were opened in, and the sidebar is
  shown in every tab; cut, yank and put move or share buffers between tabs, and tabs can be named
  and reordered from their headers
- **Vim-like reordering** — `dd` / `yy` / `p` / `P`, `<C-j>` / `<C-k>`, visual-mode selections,
  and `:PileSort`
- **Per-project sessions** — the buffer list, its order and the tabs (layout, names, and each
  tab's buffers) are saved on exit and restored on startup; named sessions let you switch between
  buffer sets
- **Edit in place** — rewrite a line of the sidebar to set a buffer's display name or a tab's name,
  or rename the file itself (`e`) and let the language server update imports
  (`workspace/willRenameFiles`)
- **At-a-glance status** — file icons, unsaved-change mark (`●`), git status letter, and a colored
  marker for every window that shows the buffer
- **Floating preview** that follows the cursor (`K`)
- **Same-name disambiguation** — `api/index.ts` and `web/index.ts` instead of two `index.ts`

## ⚡️ Requirements

- Neovim **0.10** or later
- [s1n7ax/nvim-window-picker](https://github.com/s1n7ax/nvim-window-picker) (required)
- Optional:
  - [mini.icons](https://github.com/echasnovski/mini.icons) or
    [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) for file icons
  - `git` on `$PATH` for git status marks and per-repository sessions
  - A language server that supports `workspace/willRenameFiles` to update imports on rename

## 📦 Installation

pile.nvim works without calling `setup()`; call it (or set `vim.g.pile`) only to change options.
Run `:checkhealth pile` after installing.

<details open>
<summary><a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></summary>

```lua
{
  "shabaraba/pile.nvim",
  dependencies = { "s1n7ax/nvim-window-picker" },
  lazy = false,
  opts = {},
}
```

Load it eagerly (as above) if you use `session.auto_restore`: the session is restored when the
plugin initializes, so lazy-loading on `keys` or `cmd` would restore it — and reset your window
layout — the first time you press the key.

</details>

<details>
<summary><a href="https://github.com/wbthomason/packer.nvim">packer.nvim</a></summary>

```lua
use {
  "shabaraba/pile.nvim",
  requires = { "s1n7ax/nvim-window-picker" },
  config = function()
    require("pile").setup()
  end,
}
```

</details>

<details>
<summary><a href="https://github.com/junegunn/vim-plug">vim-plug</a></summary>

```vim
Plug 's1n7ax/nvim-window-picker'
Plug 'shabaraba/pile.nvim'
```

</details>

## 🚀 Quick start

pile.nvim does not define global keymaps. A typical set:

```lua
vim.keymap.set("n", "<leader>pp", "<cmd>PileToggle<cr>", { desc = "Pile: toggle sidebar" })
vim.keymap.set("n", "]b", "<cmd>PileGoToNextBuffer<cr>", { desc = "Pile: next buffer" })
vim.keymap.set("n", "[b", "<cmd>PileGoToPrevBuffer<cr>", { desc = "Pile: previous buffer" })
```

Open the sidebar, move to a buffer and press `<CR>`. Press `dd` on a line, move, and press `p` to
put it somewhere else. Quit Neovim and start it again in the same project: the buffers come back in
that order.

## ⚙️ Configuration

Pass options to `setup()`, or set `vim.g.pile` before startup finishes — `setup()` merges its
options over `vim.g.pile`. Every option is optional. These are the defaults:

<details>
<summary>Default options</summary>

```lua
require("pile").setup({
  session = {
    auto_save = true,       -- save the buffer list to the current session on exit
    auto_restore = true,    -- restore the current session on startup (skipped when files are passed on the command line)
    preserve_order = true,  -- keep the order you set; required by reordering and :PileSort
  },

  window_indicator = {
    enabled = true,         -- mark each window that shows the buffer with a colored "█"
    colors = {              -- assigned to windows in turn
      "#E06C75", "#98C379", "#E5C07B", "#61AFEF", "#C678DD",
      "#56B6C2", "#D19A66", "#ABB2BF", "#E06C75", "#98C379",
    },
  },

  icons = {
    enabled = true,         -- mini.icons (if set up), otherwise nvim-web-devicons
  },

  marks = {
    modified = true,        -- "●" for buffers with unsaved changes
    git = true,             -- git status letter: M, A, D, R, ? ...
  },

  preview = {
    auto_open = false,      -- open the preview whenever the sidebar is focused
    border = "rounded",     -- any 'border' accepted by nvim_open_win()
  },

  rename = {
    confirm = true,         -- ask before renaming files on disk (e)
  },

  window_picker = {},       -- passed to nvim-window-picker's pick_window(), see below

  exclude = {               -- hide matching buffers
    filenames = {},         -- Lua patterns against the full buffer name, e.g. "^term://"
    filetypes = {},
    buftypes = {},
  },

  include = {               -- show matching unlisted buffers, e.g. filetypes = { "toggleterm" }
    filenames = {},
    filetypes = {},
    buftypes = {},
  },

  debug = {
    enabled = false,
    level = "info",         -- "error" | "warn" | "info" | "debug" | "trace"
  },
})
```

</details>

`window_picker` overrides your global `require("window-picker").setup()` options for pile only,
for example `{ hint = "floating-big-letter" }`. Its `filter_func` is always replaced by pile.

See [handbook/configuration.md](handbook/configuration.md) for each option in detail.

## 📖 Usage

### Commands

| Command | Description |
| --- | --- |
| `:PileToggle` | Open or close the sidebar in every tab |
| `:PileGoToNextBuffer` / `:PileGoToPrevBuffer` | Go to the next / previous buffer of the current tab's group (wraps around) |
| `:PileMoveBufferUp` / `:PileMoveBufferDown` | Move the current buffer one position within the current tab's group |
| `:PileSort[!] {key}` | Sort every group once by `name`, `path`, `extension`, `filetype` or `recent`; `!` reverses |
| `:PileSaveSession [name]` | Save the buffer list to the current session, or to `name` |
| `:PileRestoreSession [name]` | Load the buffers and windows of the current session, or of `name` |
| `:PileCreateSession {name}` | Save the buffer list as a new session (does not switch to it) |
| `:PileSwitchSession {name}` | Save the current session, then make `name` current and restore it |
| `:PileDeleteSession {name}` | Delete a session (not the current one, and never `default`) |
| `:PileListSessions` | List sessions; `*` marks the current one |
| `:PilePruneAliases` | Remove display names of files that no longer exist |

### Sidebar keymaps

| Key | Mode | Action |
| --- | --- | --- |
| `<CR>` | n | Open the buffer (asks which window when there are several) |
| `K` | n | Toggle the floating preview |
| `dd` / `d` | n / x | Cut: take the buffer(s) out of that tab and keep them in pile's register; a buffer left in no tab is closed |
| `yy` / `y` | n / x | Yank the buffer(s) into pile's register |
| `p` / `P` | n | Put the register below / above the cursor; the buffers join that group's tab |
| `D` | n | Close the buffer immediately, **discarding unsaved changes** |
| `<C-j>` / `<C-k>` | n, x | Move the buffer(s) down / up; past the end of a group, into the adjacent group |
| `<CR>` | n | On a tab header: go to that tab |
| `o` / `O` | n | On a tab header: create a tab after / before it |
| `D` | n | On a tab header: close that tab (its buffers move to `Unassigned`; the last tab stays) |
| `<C-j>` / `<C-k>` | n | On a tab header: move that tab later / earlier |
| `ciw`, `cc`, `A` ... | n | Edit a line as text: a buffer line sets its display name, a header names its tab; applied on returning to Normal mode |
| `e` | n | Edit file paths; `:w` renames files on disk, `q` cancels |

Close the sidebar with `:PileToggle` or `:close`; either closes it in every tab. The register is
cleared when you leave the sidebar window. On a tab header line, `<CR>`, `o` / `O`, `D` and
`<C-j>` / `<C-k>` act on the tab (not on the `Unassigned` header), the other keys that act on a
buffer do nothing, and `p` / `P` put at the top of that group.

pile does not change the tabline. To show tab names there, call `require("pile").tab_label(tabnr)`
from your tabline, e.g. lualine's `tabs` component (see
[Showing tab names in the tabline](handbook/api.md#showing-tab-names-in-the-tabline)).

Each line is a buffer in one tab. `yy` → another tab's group → `p` shares the buffer with that tab;
`dd` → another tab's group → `p` moves it there. Putting into `Unassigned` takes it out of every
tab. Each tab group keeps its own order.

> [!NOTE]
> `dd` used to close the buffer every time. It now closes it only when the buffer belongs to no
> other tab; otherwise it only leaves the tab, and that tab's windows switch to another buffer.

### Highlight groups

| Group | Default | Used for |
| --- | --- | --- |
| `SidebarCurrentBuffer` | `bg=#3E4452 fg=Red` | Current buffer line |
| `PileAlias` | links to `Special` | Buffers with a display name |
| `PileTabHeader` | links to `Title` | Tab header lines (`Tab 1` or the tab's name, `Unassigned`) |
| `PileModified` | links to `WarningMsg` | `●` mark |
| `PileGitModified` | links to `Changed` | `M`, `R` and other git letters |
| `PileGitAdded` | links to `Added` | `A` |
| `PileGitDeleted` | links to `Removed` | `D` |
| `PileGitUntracked` | links to `Comment` | `?` |

The `Pile*` groups are defined with `default = true`, so your colorscheme or config can override
them. `SidebarCurrentBuffer` is set unconditionally when pile initializes; override it after
`setup()`.

## 📚 Documentation

- `:help pile` — the reference, available inside Neovim
- `:checkhealth pile` — checks dependencies, options and the session directory

Detailed behavior with examples lives in [`handbook/`](handbook/):

- [Configuration](handbook/configuration.md) — every option, buffer filtering, window picker
- [Sidebar](handbook/sidebar.md) — layout, opening buffers, register, reordering, sorting, preview, marks
- [Sessions](handbook/sessions.md) — what is saved, where, and how each command behaves
- [Editing names and files](handbook/edit-mode.md) — aliases, file renames and LSP integration
- [Lua API and troubleshooting](handbook/api.md)

## 🤝 Contributing

Issues and pull requests are welcome. Commit messages and PR titles follow
[Semantic Commit Messages](https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716)
(`feat:`, `fix:`, `refactor:` ...); releases are generated by release-please. See
[CHANGELOG.md](CHANGELOG.md) for the history.

## 📄 License

[MIT](LICENSE)
