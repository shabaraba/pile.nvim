# Sessions

A pile session is a named list of files, their order in the sidebar, and the files shown in your
windows. It is **not** a Vim `:mksession` — options, folds, tabs and split geometry are not saved.

## Scope and storage

Sessions are stored per project in a JSON file under Neovim's data directory:

```
{stdpath("data")}/pile/sessions-<repo-name>-<hash>.json   -- inside a git repository
{stdpath("data")}/pile/sessions-global.json               -- anywhere else
```

The project is the git root of the current working directory (`git rev-parse --show-toplevel`), so
every directory of one repository shares the same sessions. The file holds:

- every session of the project
- which session is current (`default` until you switch)
- the display names (aliases) set with `a`, shared by all sessions of the project

The file is written atomically (temporary file + rename), so a failed write cannot corrupt it.

## What is saved

- **Buffers** — every loaded or listed buffer that has a file name and an empty `'buftype'`.
  Terminals, help pages, scratch buffers and plugin UIs are not saved. `exclude` / `include` do
  **not** apply here.
- **Order** — each buffer's position in the sidebar.
- **Windows** — the file shown in each normal (non-floating) window.

## What restore does

1. Unnamed `nofile` buffers (e.g. a dashboard) are closed.
2. Each saved file that still exists is added to the buffer list **without being loaded**. It is
   read from disk the first time you display it, so restoring many files does not start syntax,
   treesitter or language servers for all of them.
3. If windows were saved, all windows except the current one are closed (`:only`) and the saved
   files are shown in **vertical splits**, one per saved window. The original split directions
   and sizes are not restored.

Restoring **adds** buffers; buffers you already have open stay open.

## Automatic save and restore

- `session.auto_save` saves to the current session on `VimLeavePre`.
- `session.auto_restore` restores the current session 100 ms after `setup()`, unless Neovim was
  started with file arguments.

## Commands

| Command | Behavior |
| --- | --- |
| `:PileSaveSession [name]` | Save to `name`, or to the current session. Does not change the current session |
| `:PileRestoreSession [name]` | Restore `name`, or the current session. Does not change the current session |
| `:PileCreateSession {name}` | Save the current buffers as a new session `name`. Fails if it exists. Does **not** switch to it |
| `:PileSwitchSession {name}` | Save the current session, make `name` current, and restore it. Fails if `name` does not exist |
| `:PileDeleteSession {name}` | Delete `name`. The current session and `default` cannot be deleted |
| `:PileListSessions` | Print each session with its buffer count and last update; `*` marks the current one |

Session names complete with `<Tab>` for `Restore`, `Switch` and `Delete`.

### Typical workflow

```vim
" Keep a separate buffer set for a review
:PileCreateSession review
:PileSwitchSession review
" ... open the files under review ...
:PileSwitchSession default   " review is saved, default is restored
```

## Notes

- Changing the order (`<C-j>`, `p`, `:PileSort` ...) rewrites the current session's buffer list
  immediately; the windows are recorded again on the next save.
- Renaming a file with `e` updates its path in every session of the project.
- Files that no longer exist are skipped on restore and dropped on the next save.
