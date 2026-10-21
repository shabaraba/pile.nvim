# Sessions

A pile session is a named list of files, their order in the sidebar, and the tabs and splits that
show them. It is **not** a Vim `:mksession` — options, folds, cursor positions and tab-local
directories are not saved.

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
- **Windows** — for every tab page, its split layout (horizontal/vertical splits and their sizes)
  and the file shown in each normal (non-floating) window, plus the active tab and window.
  Windows that do not show a saveable file (the sidebar, terminals, help) are left out.
- **Tab groups** — for every tab page, its name and the buffers that belong to it, in the order of
  its group. Buffers that belong to no tab are saved as well and come back under `Unassigned`.
  A tab that has neither a saveable window nor a saveable buffer is not saved.

## What restore does

1. Unnamed `nofile` buffers (e.g. a dashboard) are closed.
2. Each saved file that still exists is added to the buffer list **without being loaded**. It is
   read from disk the first time you display it, so restoring many files does not start syntax,
   treesitter or language servers for all of them.
3. If windows were saved, all other tabs and windows are closed (`:tabonly`, `:only`) and each
   saved tab is rebuilt with its original split directions. Sizes are scaled to the current screen
   so the split ratios match, and the previously active tab and window are focused again. Windows
   whose file no longer exists are dropped and the remaining splits fill their space. A tab whose
   windows were all left out opens on its first buffer. If the sidebar was open, it is reopened in
   every tab.
4. Each tab gets its saved name and exactly its saved buffers, in the saved order. The other
   buffers, including those you already had open, are listed under `Unassigned`.

Restoring **adds** buffers; buffers you already have open stay open.

Sessions saved by older versions of pile have no tab groups. For them, a buffer belongs to the tabs
whose windows show it after the restore, and the other files also belong to the first tab.

## Automatic save and restore

- `session.auto_save` saves to the current session on `VimLeavePre`.
- `session.auto_restore` restores the current session 100 ms after pile initializes (once per
  Neovim instance), unless Neovim was started with file arguments.

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
  immediately; the windows and tab groups are recorded again on the next save.
- Renaming a file with `e` updates its path in every session of the project.
- Files that no longer exist are skipped on restore and dropped on the next save.
