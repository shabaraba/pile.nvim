# pile.nvim handbook

Detailed reference for pile.nvim. Start with the [README](../README.md) for installation and a
quick overview.

| Page | Covers |
| --- | --- |
| [configuration.md](configuration.md) | Every `setup()` option, buffer filtering rules, window picker options, fixed values |
| [sidebar.md](sidebar.md) | Layout, opening buffers, the register (`dd` / `yy` / `p`), reordering, `:PileSort`, navigation, preview, status marks |
| [sessions.md](sessions.md) | What a session stores, where, how restore works, every session command |
| [edit-mode.md](edit-mode.md) | Display names (`a`), file renames (`e`) and the LSP rename flow |
| [api.md](api.md) | Lua functions, health check and troubleshooting |

Inside Neovim, `:help pile` (`doc/pile.txt`) has the same reference in condensed form.

These pages describe the behavior of the code on the default branch. When you change behavior,
update the matching page and `doc/pile.txt` in the same pull request.
