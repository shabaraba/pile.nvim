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

Buffers are grouped under a header line per tab (`Tab 1`, `Tab 2`, ..., or the tab's name),
highlighted with `PileTabHeader`:

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
- Each line stands for one buffer in one tab. Cut, yank, put and reordering act on that tab's
  membership, so they can move or share a buffer between tabs (see below).
- Each tab group has its own order (see [Reordering](#reordering)).

### Tab operations on a header line

| Key | Action |
| --- | --- |
| `<CR>` | Go to that tab |
| `o` / `O` | Create a new tab after / before that tab and go to it |
| `D` | Close that tab |
| `<C-j>` / `<C-k>` | Move that tab one place later / earlier (`:tabmove`); the cursor follows the header |
| `a` | Edit names; editing a header names its tab (see [edit-mode.md](edit-mode.md#tab-names-a-on-a-header)) |

- Closing a tab from the sidebar is the same as `:tabclose`: buffers that belonged only to that tab
  are not deleted and move to `Unassigned`. Unsaved changes stay in their buffers.
- The last tab is not closed, and moving a tab stops at the first and last place. The current tab
  stays current while another tab moves.
- The `Unassigned` header has no tab, so these keys do nothing on it.

On a header line, `K`, `dd` and `yy` do nothing.

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
| `dd` | n | Cut the line under the cursor: take the buffer out of that tab |
| `d` | x | Cut the selected lines |
| `yy` | n | Yank the buffer under the cursor |
| `y` | x | Yank the selected buffers |
| `p` | n | Put below the cursor |
| `P` | n | Put above the cursor |
| `D` | n | Wipe the buffer from every tab without touching the register |

- **Cut** takes the buffer out of the tab of that line and stores its path. Windows of that tab
  that show the buffer switch to another buffer of the tab (or to an empty buffer when the tab has
  none). The buffer is wiped (like `:bwipeout`) only when it belongs to no tab any more, which
  includes cutting a line of `Unassigned`. Before wiping a buffer with unsaved changes you are
  asked to *Save*, *Discard* or *Cancel*.
- **Put** adds the stored files at the cursor position, within the group under the cursor, and
  saves the resulting order. On a header line, `p` and `P` put at the top of that group. The put
  buffers join that group's tab; a buffer the tab already has moves to the new position instead of
  appearing twice. Putting into `Unassigned` takes the buffers out of every tab.
- So `yy` → another tab's group → `p` **shares** a buffer with that tab, and `dd` → another tab's
  group → `p` **moves** it there. Within one group, `dd` → `p` moves a buffer far down the list.
- Selecting lines of several groups yanks each buffer once and cuts each line; header lines are
  skipped.
- **`D` does not ask**: unsaved changes in that buffer are lost.

> [!NOTE]
> Before tabs were grouped, `dd` always wiped the buffer. It now wipes it only when the line was
> the buffer's last tab.
- Leaving the sidebar window clears the register, so cut and put have to happen in one visit.

## Reordering

| Key / command | Action |
| --- | --- |
| `<C-j>` / `<C-k>` (normal) | Move the buffer under the cursor down / up; the cursor follows |
| `<C-j>` / `<C-k>` (visual) | Move the selected block; the selection is kept |
| `:PileMoveBufferUp` / `:PileMoveBufferDown` | Move the **current** buffer (the one in your editing window) within the current tab's group |

Moving past the first or last line of a group takes the buffer (or selection) to the adjacent
group: to the bottom of the previous group or the top of the next one. It leaves its tab and joins
the other, as with `dd` → `p`; moving into `Unassigned` takes it out of every tab. A visual
selection spanning two groups does not move. `:PileMoveBufferUp` / `:PileMoveBufferDown` stay
within the group.

Each tab group keeps its own order, so the same buffer can sit at different places in two tabs and
reordering one group leaves the others as they are. `Unassigned` follows the stored order.

The stored order is one list for all groups, and every change of order is also written to it in
the current session immediately: a move swaps places only among the buffers of that group, and a
put buffer is stored right after the buffer it follows in the group. With a single tab this is the
same as moving within the whole list. The tab groups' own orders are saved with the session's
windows (see [sessions.md](sessions.md)) and come back on restore.

Buffers that have no position yet (for example a file you just opened) are appended at the bottom
of their group.

Reordering requires `session.preserve_order = true` (the default); otherwise the sidebar is
displayed in buffer-number order.

## Sorting

`:PileSort {key}` sorts the list once and stores the result as your custom order, so you can keep
adjusting it by hand afterwards. `:PileSort! {key}` sorts in reverse. Every group is sorted, each
on its own.

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
