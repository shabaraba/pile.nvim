# Sidebar

## Layout

`:PileToggle` opens the sidebar as a 35-column split on the far left (`topleft vsplit`) and closes
it again. Each line shows, from left to right:

```
█ █  init.lua                 M ●
│ │  │  └─ name or alias        │ └─ unsaved changes
│ │  └─ file icon               └─ git status
└─┴─ one marker per window showing this buffer
```

- The current buffer is highlighted with `SidebarCurrentBuffer`; buffers with a display name use
  `PileAlias`.
- When several buffers share a file name, the shortest distinguishing directory is prepended
  (`api/index.ts`, `web/index.ts`).
- The sidebar redraws itself on buffer and window events (debounced), so it follows `:edit`,
  `:bdelete`, splits and so on without manual refresh.

Which buffers appear is described in
[configuration.md](configuration.md#exclude--include).

## Opening a buffer

`<CR>` opens the buffer under the cursor:

| Candidate windows | Result |
| --- | --- |
| None | A new vertical split is created next to the sidebar |
| One | The buffer is opened there |
| Two or more | nvim-window-picker asks which window to use |

Candidates are normal (non-floating) windows other than the sidebar, excluding windows that show a
`nofile` / `popup` buffer or a `notify` window.

## Register: cut, yank and put

The sidebar has its own register, separate from Vim registers. It holds buffers, not text.

| Key | Mode | Action |
| --- | --- | --- |
| `dd` | n | Cut the buffer under the cursor |
| `d` | x | Cut the selected buffers |
| `yy` | n | Yank the buffer under the cursor |
| `y` | x | Yank the selected buffers |
| `p` | n | Put below the cursor |
| `P` | n | Put above the cursor |
| `D` | n | Wipe the buffer without touching the register |

- **Cut** wipes the buffers (like `:bwipeout`) and stores their paths. If any of them has unsaved
  changes you are asked to *Save*, *Discard* or *Cancel* first.
- **Put** re-adds the stored files at the cursor position and saves the resulting order to the
  current session. Use `dd` → move → `p` to move a buffer far down the list.
- **`D` does not ask**: unsaved changes in that buffer are lost.
- Leaving the sidebar window clears the register, so cut and put have to happen in one visit.

## Reordering

| Key / command | Action |
| --- | --- |
| `<C-j>` / `<C-k>` (normal) | Move the buffer under the cursor down / up; the cursor follows |
| `<C-j>` / `<C-k>` (visual) | Move the selected block; the selection is kept |
| `:PileMoveBufferUp` / `:PileMoveBufferDown` | Move the **current** buffer (the one in your editing window) |

Every change of order is written to the current session immediately. Buffers that have no stored
position yet (for example a file you just opened) are appended at the bottom.

Reordering requires `session.preserve_order = true` (the default); otherwise the sidebar is
displayed in buffer-number order.

## Sorting

`:PileSort {key}` sorts the list once and stores the result as your custom order, so you can keep
adjusting it by hand afterwards. `:PileSort! {key}` sorts in reverse.

| Key | Order |
| --- | --- |
| `name` | File name, case-insensitive |
| `path` | Full path, case-insensitive |
| `extension` | File extension, case-insensitive |
| `filetype` | `'filetype'` |
| `recent` | Most recently used first |

Ties are broken by full path, so the result is deterministic. Requires
`session.preserve_order = true`.

## Navigation

`:PileGoToNextBuffer` / `:PileGoToPrevBuffer` switch the current window to the next / previous
buffer **in sidebar order**, wrapping around at either end. They work whether the sidebar is open or
not. They do nothing when the current buffer is not in the list (e.g. a help window).

## Preview

`K` toggles a floating preview to the right of the sidebar. While it is on, it follows the cursor.

- Loaded buffers are shown directly, positioned at the last cursor position (`'"` mark).
- Buffers that are not loaded yet (e.g. restored from a session) are shown through a scratch copy
  of the file, so previewing does not fire `BufRead` autocommands or start language servers.
- The preview closes when you leave the sidebar. With `preview.auto_open = true` it reopens every
  time you enter the sidebar.

## Status marks

| Mark | Meaning |
| --- | --- |
| `●` | The buffer has unsaved changes |
| `M` | Modified |
| `A` | Added (staged) |
| `D` | Deleted |
| `R` | Renamed |
| `?` | Untracked |

Other porcelain letters (`C`, `U`, `T`) are shown as is. See
[configuration.md](configuration.md#marks) for when git status is refreshed.
