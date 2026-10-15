# Lua API and troubleshooting

## Lua API

User commands are the supported interface. For keymaps you can also call these functions directly:

```lua
local pile = require("pile")

pile.setup(opts)               -- see configuration.md
pile.toggle_sidebar()          -- :PileToggle
pile.switch_to_next_buffer()   -- :PileGoToNextBuffer
pile.switch_to_prev_buffer()   -- :PileGoToPrevBuffer
pile.move_buffer_up()          -- :PileMoveBufferUp
pile.move_buffer_down()        -- :PileMoveBufferDown
```

```lua
vim.keymap.set("n", "<leader>pp", require("pile").toggle_sidebar, { desc = "Pile: toggle sidebar" })
```

Modules under `pile.*` other than `pile` itself are internal and may change without notice.

## Troubleshooting

### `pile.nvim requires s1n7ax/nvim-window-picker to be installed`

The dependency is missing or loads after pile. Add it to `dependencies` (lazy.nvim) / `requires`
(packer). `setup()` registers nothing until it can be required.

### `E492: Not an editor command: PileToggle`

`setup()` was not called. With lazy.nvim, `opts = {}` (or `config = true`) is enough.

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
