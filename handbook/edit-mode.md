# Editing names and files

Like oil.nvim, the sidebar can be edited as text.

- **Display names and tab names** are edited directly in the sidebar: change a line with `ciw`,
  `cc`, `A`, `r` ... and the name is applied when you return to Normal mode.
- **File paths** are edited in a separate mode: `e` turns the list into an editable buffer of
  paths, and `:w` renames the files.

## Editing the sidebar directly

- A buffer line sets its alias, a tab header line names its tab.
- The change is applied on leaving Insert mode, or right after a Normal-mode change such as `r`,
  `x` or `~`, and the sidebar is redrawn. Undo is off in the sidebar, so `u` does not bring back
  an old name; set the name again instead.
- The sidebar is not redrawn while you are in Insert mode, so the line you are typing is kept.
- The sidebar keymaps still apply: `dd`, `yy`, `p` / `P`, `D`, `o` / `O`, `<CR>` and
  `<C-j>` / `<C-k>` act on buffers and tabs, not on the text.
- Each line stays tied to its header or buffer: **do not add or delete lines** (e.g. `J`, `dj`).
  A changed line count is reported as an error and the sidebar is redrawn without applying
  anything.
- An alias belongs to the buffer, not to one line. When a buffer appears in several groups,
  editing one of its lines is enough; if one change edits several of them (e.g. `:%s`), they must
  have the same text, or an error is reported and nothing is applied.

## Tab names (header lines)

Edit a tab header line to name the tab; the header shows the name instead of `Tab N`.

- Empty the line, or set it back to `Tab N`, to remove the name.
- The `Unassigned` header cannot be renamed, and `e` does not edit headers; an error is reported
  and nothing is applied.
- The name is stored in the tab-local variable `t:pile_name`, so a tabline can show it, e.g.
  `gettabvar(tabnr, 'pile_name')` or `vim.t[tabpage].pile_name`. The variable is removed when the
  name is.
- Tab names are saved with the session (see [sessions.md](sessions.md)).

## Display names (buffer lines)

An alias replaces the file name in the sidebar only; the buffer and the file keep their names.

- Change a buffer line in the sidebar to set the alias.
- Empty the line, or set it back to the original name, to remove the alias.
- Aliases are keyed by absolute path and stored per project, shared by all sessions
  (see [sessions.md](sessions.md)).
- Aliased lines are highlighted with `PileAlias`.
- When a buffer is renamed in Neovim by other means (`:file`, `:saveas`, oil.nvim, an LSP rename
  ...), its alias and its position in the stored sessions move to the new path.
- A file moved outside Neovim (e.g. `mv` in a shell) keeps its alias on the old path, and the alias
  comes back if a file appears there again. `:PilePruneAliases` removes the aliases of paths that
  neither exist on disk nor are open as a buffer.

## File renames (`e`)

`e` replaces the sidebar with an editable buffer of the same lines, the tab headers included, with
each buffer line showing the path relative to the current directory. Edit a path to rename or move
the file; an absolute path or `~/...` also works. Missing parent directories are created.

While editing:

- The winbar shows `pile: edit paths` with a reminder of the keys.
- The sidebar keymaps are off, so `dd`, `p`, `x` ... are ordinary text editing.
- `q` discards the changes and returns to the sidebar.
- Do not add, delete or reorder lines; `:w` rejects a changed line count. When a buffer appears in
  several groups, its edited lines must have the same path.
- When validation fails or you decline the confirmation, you stay in edit mode and can fix the text.

`:w` runs these steps:

1. **Validate** all changes. Nothing is renamed if any of these fail:
   - a line is empty
   - two buffers would get the same path
   - the target already exists (a case-only rename on a case-insensitive filesystem is allowed)
   - the buffer has unsaved changes — write it first
2. **Confirm** — with `rename.confirm = true`, the list of `old -> new` paths is shown and you
   choose *Yes* / *No*.
3. **`workspace/willRenameFiles`** is sent to every attached language server that supports it,
   all at once, waiting up to 3 seconds. The returned workspace edits are applied — this is what
   updates import paths (e.g. with `ts_ls` / `vtsls`).
4. **Rename** each file on disk and point its buffer to the new path. A loaded buffer is written
   once with `:noautocmd write!` so that later `:w` works (formatters and other `BufWrite` hooks
   do not run).
5. **`workspace/didRenameFiles`** is sent to servers that support it. Aliases and session entries
   follow the new paths.

If renaming fails part-way, files already renamed stay renamed and the error is reported.

Import updates only reach files the language server knows about, and their buffers are modified
but not written — review them and `:wa`.
