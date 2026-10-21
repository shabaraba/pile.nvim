# Sidebar

## Layout

`:PileToggle` opens the sidebar as a 35-column split on the far left (`topleft vsplit`) and closes
it again. While it is open, every tab has one, including tabs you create later; all of them show
the same list. Closing it (`:PileToggle`, or `:close` / `:only` on the sidebar window) closes it in
every tab. Each buffer line shows, from left to right:

```
█ █  init.lua                 M ●
│ │  │  └─ name or alias        │ └─ unsaved changes
│ │  └─ file icon               └─ git status
└─┴─ one marker per window of that tab showing this buffer
```

- The current buffer is highlighted with `SidebarCurrentBuffer` in the current tab's group;
  buffers with a display name use `PileAlias`.
- When several buffers share a file name, the shortest distinguishing directory is prepended
  (`api/index.ts`, `web/index.ts`).
- The sidebar redraws itself on buffer and window events (debounced), so it follows `:edit`,
  `:bdelete`, splits and so on without manual refresh.

Which buffers appear is described in
[configuration.md](configuration.md#exclude--include).

## Tab groups

Buffers are grouped under a header line per tab (`Tab 1`, `Tab 2`, ...), highlighted with
`PileTabHeader`:

```
Tab 1
 init.lua
 config.lua
Tab 2
 config.lua
 README.md
Unassigned
 notes.md
```

(The buffer lines start with their icon, which sets them apart from the headers.)

- A buffer belongs to a tab once it is added to the buffer list (`:edit`, `:badd`) or entered in
  that tab. It stays in the group when no window shows it any more.
- A buffer can belong to several tabs and then appears in each of their groups.
- When a tab is closed, buffers that belonged only to it are kept, under `Unassigned` at the end.
  The `Unassigned` group is shown only when it has buffers.
- Each group follows the stored order of the whole list (see [Reordering](#reordering)).

### Tab operations on a header line

| Key | Action |
| --- | --- |
| `<CR>` | Go to that tab |
| `o` / `O` | Create a new tab after / before that tab and go to it |
| `D` | Close that tab |

- Closing a tab from the sidebar is the same as `:tabclose`: buffers that belonged only to that tab
  are not deleted and move to `Unassigned`. Unsaved changes stay in their buffers.
- The last tab is not closed.
- The `Unassigned` header has no tab, so these keys do nothing on it.

On a header line, `K`, `dd`, `yy` and `<C-j>` / `<C-k>` do nothing.

## Opening a buffer

`<CR>` opens the buffer under the cursor:

| Candidate windows | Result |
| --- | --- |
| None | A new vertical split is created next to the sidebar |
| One | The buffer is opened there |
| Two or more | nvim-window-picker asks which window to use |

Candidates are normal (non-floating) windows of the current tab other than the sidebar, excluding windows that show a
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
- **Put** re-adds the stored files at the cursor position, within the group under the cursor, and
  saves the resulting order to the current session. On a header line, `p` and `P` put at the top of
  that group. The put buffers join that group's tab. Use `dd` → move → `p` to move a buffer far
  down the list.
- Selecting lines of several groups yanks or cuts each buffer once; header lines are skipped.
- **`D` does not ask**: unsaved changes in that buffer are lost.
- Leaving the sidebar window clears the register, so cut and put have to happen in one visit.

## Reordering

| Key / command | Action |
| --- | --- |
| `<C-j>` / `<C-k>` (normal) | Move the buffer under the cursor down / up; the cursor follows |
| `<C-j>` / `<C-k>` (visual) | Move the selected block; the selection is kept |
| `:PileMoveBufferUp` / `:PileMoveBufferDown` | Move the **current** buffer (the one in your editing window) within the current tab's group |

Moves stay within one group: a buffer does not move past the first or last line of its group, and
a visual selection spanning two groups does not move.

The stored order is one list for all groups. A move swaps places only among the buffers of that
group, so buffers outside it keep their places and other groups keep their order. A put buffer is
stored right after the buffer it follows in the group. With a single tab this is the same as moving
within the whole list.

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
buffer **of the current tab's group, in sidebar order**, wrapping around at either end. They work
whether the sidebar is open or not. They do nothing when the current buffer is not in the group
(e.g. a help window).

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
