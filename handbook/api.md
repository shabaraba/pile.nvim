# Lua API and troubleshooting

## Lua API

User commands are the supported interface. For keymaps you can also call these functions directly:

```lua
local pile = require("pile")

pile.setup(opts)               -- optional, see configuration.md
pile.toggle_sidebar()          -- :PileToggle
pile.switch_to_next_buffer()   -- :PileGoToNextBuffer
pile.switch_to_prev_buffer()   -- :PileGoToPrevBuffer
pile.move_buffer_up()          -- :PileMoveBufferUp
pile.move_buffer_down()        -- :PileMoveBufferDown
pile.tab_label(tabnr)          -- name of tab `tabnr` (nil or 0: current), see below
```

```lua
vim.keymap.set("n", "<leader>pp", require("pile").toggle_sidebar, { desc = "Pile: toggle sidebar" })
```

These functions initialize pile on first use if it has not initialized yet, except `tab_label`,
which only reads the name. Modules under `pile.*` other than `pile` itself are internal and may
change without notice.

### Showing tab names in the tabline

Neovim's tabs have no names, and the default tabline shows the buffer of each tab. pile does not
set `'tabline'`; to show the names given in the sidebar (see
[edit-mode.md](edit-mode.md)), call `tab_label()` from your tabline.
It returns the same text as the sidebar header: the name, or `Tab N` when the tab has none.

With [lualine](https://github.com/nvim-lualine/lualine.nvim):

```lua
tabline = {
  lualine_a = {
    { "tabs", mode = 1, fmt = function(_, context) return require("pile").tab_label(context.tabnr) end },
  },
},
```

With your own `'tabline'`:

```lua
function _G.pile_tabline()
  local current, parts = vim.fn.tabpagenr(), {}
  for i = 1, vim.fn.tabpagenr("$") do
    local label = require("pile").tab_label(i):gsub("%%", "%%%%")
    table.insert(parts, (i == current and "%#TabLineSel#" or "%#TabLine#") .. "%" .. i .. "T " .. label .. " ")
  end
  return table.concat(parts) .. "%#TabLineFill#%T"
end
vim.o.tabline = "%!v:lua.pile_tabline()"
```

To fall back to your tabline's own label for unnamed tabs, read the tab-local variable instead:
`vim.t[tabpage].pile_name` (or `gettabvar(tabnr, 'pile_name')`) is `nil` / empty when the tab has
no name.

## Health check

`:checkhealth pile` checks:

- the Neovim version (0.10+)
- nvim-window-picker, the icon provider and the `git` executable
- option types and `exclude` / `include` filename patterns
- whether the session directory is writable

## Troubleshooting

Start with `:checkhealth pile`.

### `pile.nvim: s1n7ax/nvim-window-picker is not installed`

The dependency is missing or loads after pile. Add it to `dependencies` (lazy.nvim) / `requires`
(packer). Until then, `<CR>` in the sidebar fails when there are several windows to choose from.

### `E492: Not an editor command: PileToggle`

`plugin/pile.lua` was not sourced: the plugin is not on `'runtimepath'`, or your plugin manager has
not loaded it yet (lazy-loading). Commands exist as soon as the plugin is loaded.

### A buffer is missing from the sidebar

The sidebar shows listed buffers only. Check `:ls!` — if the buffer is marked `u` (unlisted), add it
with `include`. Also check your `exclude` patterns. See
[configuration.md](configuration.md#exclude--include).

### Reordering or `:PileSort` does nothing

`session.preserve_order` must be `true`.

### The sidebar shows buffers from another project

Sessions are keyed by the git root of the **current directory** at the time of the call. After
`:cd` into another repository, the other project's session and order apply.

### Git marks do not appear

`git` must be on `$PATH` and the file must be inside a repository. Marks refresh only while the
sidebar is open; focus Neovim again or write the file to trigger a refresh.

### Collecting a log

```lua
require("pile").setup({ debug = { enabled = true, level = "debug" } })
```

Reproduce the problem and include the `[pile.nvim]` messages (`:messages`) in the issue.
