# Editing names and files

Like oil.nvim, the sidebar can be edited as text. Press a key to turn the list into an editable
buffer, change lines, and `:w` to apply.

| Key | Edits | `:w` does |
| --- | --- | --- |
| `a` | Display names | Saves aliases shown in the sidebar |
| `e` | File paths, relative to the current directory | Renames / moves the files on disk |

While editing:

- The winbar shows `pile: edit names` / `pile: edit paths` with a reminder of the keys.
- The sidebar keymaps are off, so `dd`, `p`, `x` ... are ordinary text editing.
- `q` discards the changes and returns to the sidebar.
- Each line stays tied to its buffer: **do not add, delete or reorder lines**. `:w` rejects a
  changed line count; the list order is not changed by edit mode.
- When validation fails or you decline the confirmation, you stay in edit mode and can fix the text.

## Display names (`a`)

An alias replaces the file name in the sidebar only; the buffer and the file keep their names.

- Change a line and `:w` to set the alias.
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

Each line starts as the path relative to the current directory. Edit it to rename or move the file;
an absolute path or `~/...` also works. Missing parent directories are created.

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
