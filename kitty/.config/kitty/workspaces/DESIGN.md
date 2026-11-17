# kitty-workspaces: design

Rex-like persistent workspaces for kitty, using zmx for process persistence.

## Model

    workspace  (one per kitty OS window at a time)
      tab      (a kitty tab; a list of windows)
        window (a kitty window/split; backed by exactly one zmx session)

- Every window has a stable ID, `win-<8 hex>`. The zmx session name is that ID.
- Labels are human names and may change. IDs never change and are never shown
  as the primary handle.
- A tab has no state of its own. It is detached when all of its windows are detached.
- A workspace has no open/closed flag. "Open" means some kitty OS window carries
  its ID in a user variable (see Linkage).

## Storage

- Directory: `~/.local/share/kitty-workspaces/` (override with `KITTY_WORKSPACES_DIR`, used by tests).
- One file per workspace: `<ws-id>.json`, e.g. `ws-7f3a1c2b.json`.
- Writes are atomic (temp file + `os.replace`).
- Schema v1:

      {
        "version": 1,
        "id": "ws-7f3a1c2b",
        "label": "api",
        "tabs": [
          {
            "id": "tab-91c0d4e2",
            "label": "editor",
            "windows": [
              {"id": "win-2b7e9a10", "label": "shell", "cwd": "/Users/suk/src/api", "state": "detached"}
            ]
          }
        ]
      }

- `state` is `open` or `detached`. Open/detached is the only window state stored.
  A stored `open` can be stale after a crash, so opening a workspace always
  re-derives liveness from kitty (see Opening).

## Linkage between kitty and the store

- Each kitty window that belongs to a workspace gets two user variables, set
  with `kitten @ set-user-vars` right after it is launched:
  `kitty_workspace=<ws-id>` and `kitty_window=<win-id>`.
- A window's workspace is read from its user variables. Nothing is keyed on
  OS-window IDs, which are not stable across restarts.

## Lifecycle and keys

| Key | Action |
|---|---|
| cmd+n | New OS window running the picker (its own window, so no overlay); pick a workspace, or "n" for a new one. Cancelling leaves no window behind |
| cmd+t | New tab in the current workspace (creates a workspace if the window has none) |
| ctrl+s, v / n | Vertical / horizontal split; launched through the same kitten so the new window is zmx-backed |
| cmd+w | Detach: close the kitty window; zmx keeps running; state becomes `detached` |
| cmd+shift+w | Close this workspace's windows in this OS window: detached, not killed. Plain windows in that OS window stay |
| ctrl+s, shift+x | Kill one window: `zmx kill`, remove it from the store, close it |
| picker "x N" | Kill a workspace (after confirmation): its zmx sessions end, its windows close, the workspace is deleted |
| cmd+k | Picker: open the chosen workspace in the current OS window (switches out the current workspace). If already open, focus it |
| picker "d" | List detached windows; "r <n>" reattaches one, "p <n>" prunes one |
| ctrl+s, w, r | Rename the current workspace (label only) |

- Autosave happens at each step: the kitten writes the file when it creates a
  window, and the watcher writes it when a window closes. No polling.
- Every new window is zmx-backed, including splits.
- Removed binding: `cmd+w close_os_window` (replaced by detach).

## Watcher (autosave on close)

- `workspace_watcher.py` is loaded for every window with `watcher workspace_watcher.py` in kitty.conf.
- `on_close`: read the window's `kitty_workspace` and `kitty_window` user variables.
  If the window is in the file, set `state=detached` and save. If not (already killed), do nothing.
- The kill kitten removes the window from the file before it closes the window,
  so the watcher's on_close finds nothing to change.
- The watcher runs inside kitty's process. It may only import the pure
  `workspaces` package, never kitten or kitty-internal modules.

## Opening a workspace (cmd+k)

The picker runs as an overlay over the window the user was in (the "anchor").
The anchor is found with `kitten @ ls --match state:overlay_parent`; kittens
never act on their own overlay window ID.

1. If the workspace is already open anywhere (a window carries its ID), focus it and stop.
2. Otherwise open its tabs in the anchor's OS window: the first window of each tab
   is a new tab (`--type=tab --match id:<anchor>`), the others are splits
   (`--type=window --location=vsplit`). Each runs `zmx attach <win-id>` in its saved cwd.
3. Set the user variables and mark each window `open`.
4. Switch: if the anchor belonged to another workspace, that workspace's windows
   in this OS window are marked `detached` and closed. Their zmx sessions keep
   running. The anchor is closed last, because the picker overlay runs over it.

Each OS window therefore holds at most one workspace at a time. cmd+k replaces
the current one in place rather than opening a new OS window.

Layout is an ordered list of tabs and windows. Split geometry is not restored (v1).


## Reattaching and pruning detached windows

cmd+k on an open workspace only focuses it. Detached windows are never restored
automatically.

The picker's "d" entry lists every stored window that is not open in kitty.
- "r <n>" reattaches one into its workspace's open OS window: beside a window of its
  own tab if one is open, otherwise as a new tab. Only for open workspaces.
- "p <n>" prunes one: ends its zmx session and removes it from the store. Refuses an
  open window. The workspace itself is kept.

This is Rex's model: detach keeps a block running out of its window, and
session.move_block places it again on request. Rex has no automatic restore either.

## Startup restore (opt-in)

`_open.json` in the store records the
workspaces that were open when last changed (opened, switched out, closed with
cmd+shift+w, killed). It is not updated on quit, so a plain quit still counts as
"open". With `startup_session ~/.config/kitty/workspaces/startup.session` enabled
in kitty.conf, `restore_on_launch.py` opens each listed workspace in its own OS window.
Off by default.

## Renaming, killing whole workspaces

- Rename changes only `label`. The ID is unchanged.
- Killing a whole workspace is not in v1.

## Concurrency (v1)

Kittens and the watcher both read and write the same file. The write is atomic,
but a read-modify-write race is possible if two windows change at the same
moment. Accepted for v1; a lock file is the next step if it shows up.

## Non-goals (v1)

- Restoring split geometry.
- Detecting zmx session liveness.
- Syncing across machines.
- Kitty's native sessions (`save_as_session`); this project replaces that use case.

## Verification status

Documented in kitty 0.50 docs, not yet run live:
- Watcher callbacks `on_close`, `on_set_user_var`, `on_resize`, and the
  `window.user_vars` attribute.
- `kitten @ ls` reports user variables; `set-user-vars` and `launch` print the new window ID.
- `match var:key=value` works for focusing an open workspace.
- A kitten mapping runs without a visible overlay (affects cmd+t/cmd+n).
- Three-key chords (`ctrl+s>w>r`) work.
- `close_window` does not prompt when a zmx client is running.

Unit tests cover the pure logic: model operations, storage, and argv building.
