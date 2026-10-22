# Configuration

Every key is optional; anything you leave out keeps its default. The full default table is in the
[README](../README.md).

## How options are applied

pile.nvim initializes itself once Neovim has started (`plugin/pile.lua`, on `VimEnter`), so
`setup()` is optional. There are two ways to pass options:

```lua
-- 1. A global, read when pile initializes
vim.g.pile = { marks = { git = false } }

-- 2. setup(); its options are merged over vim.g.pile
require("pile").setup({ marks = { git = false } })
```

- If you call `setup()` before startup finishes (directly in `init.lua`, or through a plugin
  manager's `opts` / `config`), the automatic initialization is skipped.
- Calling `setup()` again replaces the configuration (it is merged over `vim.g.pile`, not over the
  previous call) and does not register autocommands twice.
- When [nvim-window-picker](https://github.com/s1n7ax/nvim-window-picker) cannot be required, a
  warning is shown once and everything except choosing among several windows keeps working.
- `:checkhealth pile` reports invalid option types and malformed `filenames` patterns.

## `session`

| Key | Default | Description |
| --- | --- | --- |
| `auto_save` | `true` | On `VimLeavePre`, save the buffer list and windows to the **current** session |
| `auto_restore` | `true` | Shortly after initialization (100 ms), restore the current session. Skipped when Neovim was started with file arguments (`nvim foo.lua`) |
| `preserve_order` | `true` | Show buffers in the order stored in the current session. When `false`, the sidebar uses buffer-number order, reordering keys have no visible effect and `:PileSort` refuses to run |

See [sessions.md](sessions.md) for what a session contains.

## `window_indicator`

| Key | Default | Description |
| --- | --- | --- |
| `enabled` | `true` | Prefix each line with one `█` per window that currently shows the buffer |
| `colors` | 10 colors (see README) | Colors assigned to windows in the order they first appear; the list wraps around |

The window's `CursorLineNr` is also tinted with its color (via `'winhighlight'`, keeping any entries
you already set), so you can match a marker to its window.

## `icons`

| Key | Default | Description |
| --- | --- | --- |
| `enabled` | `true` | Show a file icon before the name |

The provider is chosen once, on first use: `mini.icons` if `MiniIcons` has been set up, otherwise
`nvim-web-devicons`. With neither installed, no icon is shown.

## `marks`

Right-aligned marks at the end of each line.

| Key | Default | Description |
| --- | --- | --- |
| `modified` | `true` | `●` while the buffer has unsaved changes |
| `git` | `true` | One-letter git status of the file |

The git letter comes from `git status --porcelain=v1 --untracked-files=all`, run asynchronously per
repository. When a file has both staged and unstaged changes, the unstaged (worktree) side wins.
`??` is shown as `?`. Git status is only refreshed while the sidebar is open: when it opens, on
`BufReadPost` / `BufWritePost`, and on `FocusGained`, `ShellCmdPost` and `TermLeave`.

## `preview`

| Key | Default | Description |
| --- | --- | --- |
| `auto_open` | `false` | Open the preview every time the sidebar window is entered, instead of only with `K` |
| `border` | `"rounded"` | Border of the floating window; any value `nvim_open_win()` accepts |

## `rename`

| Key | Default | Description |
| --- | --- | --- |
| `confirm` | `true` | List the `old -> new` paths and ask before renaming files with `e` |

## `tabline`

| Key | Default | Description |
| --- | --- | --- |
| `enabled` | `false` | Set `'tabline'` to pile's tabline, which shows each tab's name (or `Tab N`) |

pile's tabline replaces any `'tabline'` set before `setup()`, so leave it off when you use a tabline
plugin such as lualine or bufferline.nvim and call `tab_label()` from it instead (see
[api.md](api.md#showing-tab-names-in-the-tabline)). Turning the option off again removes pile's
tabline only if it is still the one set. Whether the tabline is shown at all still follows
`'showtabline'` (by default, only with two or more tabs).

## `window_picker`

Default: `{}`.

When more than one window can receive a buffer, `<CR>` in the sidebar calls
`require("window-picker").pick_window(opts)`. The `window_picker` table is used as `opts`, so it
overrides your global `require("window-picker").setup()` options for pile's picker only.
`filter_func` is always replaced: pile restricts the candidates to normal (non-floating) windows
other than the sidebar that do not show a `nofile` / `popup` buffer or `notify` window.

```lua
window_picker = {
  hint = "floating-big-letter",          -- or "statusline-winbar"
  selection_chars = "FJDKSLA;CMRUEIWOQP",
  prompt_message = "Pick window to open buffer: ",
},
```

## `exclude` / `include`

Both take the same three fields. A buffer matches a rule when **any** field matches.

| Field | Matched against |
| --- | --- |
| `filenames` | Lua patterns (not globs) against the full buffer name. An invalid pattern is ignored with a one-time warning |
| `filetypes` | Exact `'filetype'` values |
| `buftypes` | Exact `'buftype'` values |

The sidebar decides what to show in this order:

1. **Listed** buffers (`'buflisted'`, i.e. what `:ls` shows) are candidates.
2. **Unlisted** buffers are candidates only when they are loaded and match `include`.
3. Candidates are then dropped when any of these hold:
   - the buffer has no name, or its `'buftype'` is `nofile` or `popup`
   - its `'filetype'` is `notify`, or it is an oil.nvim buffer (`oil*` filetype or `oil://` name)
   - it matches `exclude` — so `exclude` always wins over `include`

Examples:

```lua
-- Hide terminals opened with :terminal
exclude = { buftypes = { "terminal" } },

-- Show toggleterm terminals (they are unlisted)
include = { filetypes = { "toggleterm" } },

-- Hide fugitive buffers
exclude = { filenames = { "^fugitive://" } },
```

`exclude` / `include` only affect the sidebar and `:PileGoTo*Buffer`. Sessions save every named
file buffer regardless (see [sessions.md](sessions.md)).

## `debug`

| Key | Default | Description |
| --- | --- | --- |
| `enabled` | `false` | Emit pile's internal log through `vim.notify` |
| `level` | `"info"` | Maximum level shown: `"error"`, `"warn"`, `"info"`, `"debug"`, `"trace"` |

Messages are prefixed with `[pile.nvim][<level>]`. `debug` and `trace` are verbose (the whole
buffer list is logged on every redraw); use them only to investigate a problem.

## Fixed values

These are not configurable at the moment:

- Sidebar position and width: left side, 35 columns
- Preview width: up to 100 columns
- Timeout for `workspace/willRenameFiles` responses: 3 seconds
