"""Lifecycle actions behind the kittens and the watcher. See DESIGN.md.

Each function reads the current kitty state, changes the store, then performs
kitty actions. Save happens before the kitty action that a crash could interrupt.
"""

from __future__ import annotations

import subprocess
from typing import Any

from . import kitty_cmd as kc
from . import kitty_remote as kr
from . import ops, storage
from .models import STATE_DETACHED, Workspace


def _launch_zmx_window(
    kind: str,
    win_id: str,
    cwd: str | None,
    match: str | None,
    tab_label: str | None,
    location: str | None = None,
) -> int:
    return kr.launch(
        kind,
        kc.zmx_attach_argv(win_id),
        cwd=cwd,
        match=match,
        tab_title=tab_label,
        location=location,
    )


def _kill_zmx(win_id: str) -> None:
    subprocess.run([kc.zmx_bin(), "kill", win_id], capture_output=True, text=True)


def create_workspace() -> Workspace:
    """A new workspace with one shell window. The caller opens it (cmd+n picker, 'new' entry)."""
    ws = ops.new_workspace(label=f"workspace {len(storage.list_all()) + 1}")
    win = ops.add_window(ws, label="shell", cwd=None)
    ops.set_state(ws, win.id, STATE_DETACHED)  # not open until open_workspace succeeds
    storage.save(ws)
    return ws


def new_window(
    kitty_win_id: int | None, where: str = "tab", cwd: str | None = None
) -> str:
    """cmd+t (where='tab'), ctrl+s v (where='vsplit'), ctrl+s n (where='hsplit').

    Adds a zmx-backed window to the current workspace. Starts a new workspace if
    the current window has none. A split goes into the current window's tab.
    """
    if where not in kc.PLACEMENTS:
        raise ValueError(f"unknown placement {where!r}")
    state: list[dict[str, Any]] = kr.ls()
    if cwd is None and kitty_win_id is not None:
        cwd = kc.window_cwd(state, kitty_win_id)
    ws_id = kc.current_workspace_id(state, kitty_win_id)
    ws = storage.load(ws_id) if ws_id else None
    if ws is None:
        ws = ops.new_workspace(label=f"workspace {len(storage.list_all()) + 1}")
        where = "tab"  # nothing to split from yet

    tab_id = None
    cur_win = kc.window_var(state, kitty_win_id, kc.VAR_WINDOW)
    if where != "tab" and cur_win:
        tab = ops.tab_for_window(ws, cur_win)
        tab_id = tab.id if tab else None
    if where != "tab" and tab_id is None:
        where = "tab"

    win = ops.add_window(ws, label="shell", cwd=cwd, tab_id=tab_id)
    if where == "tab":
        match = f"id:{kitty_win_id}" if kitty_win_id is not None else None
        kid = _launch_zmx_window("tab", win.id, cwd, match, "shell")
    else:
        kid = _launch_zmx_window(
            "window", win.id, cwd, f"id:{kitty_win_id}", None, location=where
        )
    kr.run_set_vars(kid, ws.id, win.id)
    storage.save(ws)
    return ws.id


def kill_window(kitty_win_id: int) -> bool:
    """ctrl+s, shift+x: remove one window from its workspace, kill its zmx session, close it."""
    state = kr.ls()
    ws_id = kc.current_workspace_id(state, kitty_win_id)
    win_id = kc.window_var(state, kitty_win_id, kc.VAR_WINDOW)
    ws = storage.load(ws_id) if ws_id else None
    if ws is not None and win_id:
        ops.remove_window(ws, win_id)
        storage.save(ws)
    if win_id:
        _kill_zmx(win_id)
    kr.run_close(kitty_win_id)
    return win_id is not None


def kill_workspace(ws_id: str, anchor: int | None) -> int:
    """Kill a workspace: its zmx sessions die, its windows close, and it is deleted.

    Returns the number of windows it had. The store entry goes first, so the watcher
    sees nothing to detach when the kitty windows close. The anchor closes last, since
    the picker overlay may be running over it.
    """
    ws = storage.load(ws_id)
    if ws is None:
        raise KeyError(ws_id)
    state = kr.ls()
    open_map = kc.open_window_map(state, ws_id)
    storage.delete(ws_id)
    storage.remove_open_id(ws_id)
    for tab in ws.tabs:
        for win in tab.windows:
            _kill_zmx(win.id)
    for kid in open_map.values():
        if kid != anchor:
            kr.run_close(kid)
    if anchor is not None and anchor in open_map.values():
        kr.run_close(anchor)
    return sum(len(t.windows) for t in ws.tabs)


def close_workspace_window(anchor: int) -> int:
    """cmd+shift+w: close this workspace's windows in the current OS window (Rex's 'close
    workspace window'). They are detached, not killed, and the workspace stays in the
    store. Plain windows in that OS window are left alone. Returns how many closed.
    """
    state = kr.ls()
    ws_id = kc.current_workspace_id(state, anchor)
    if not ws_id:
        return 0
    ws = storage.load(ws_id)
    mine = [
        w
        for w in kc.os_window_windows(state, anchor)
        if (w.get("user_vars") or {}).get(kc.VAR_WORKSPACE) == ws_id
    ]
    if ws is not None:
        for w in mine:
            win_id = (w.get("user_vars") or {}).get(kc.VAR_WINDOW)
            if win_id:
                ops.set_state(ws, win_id, STATE_DETACHED)
        storage.save(ws)
    storage.remove_open_id(ws_id)
    # Anchor last: it may be the window the kitten runs in.
    for w in sorted(mine, key=lambda w: w.get("id") == anchor):
        kr.run_close(w["id"])
    return len(mine)


def rename_workspace(ws_id: str, label: str) -> None:
    ws = storage.load(ws_id)
    if ws is None:
        raise KeyError(ws_id)
    ops.rename(ws, label)
    storage.save(ws)


def detached_windows(state: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Every stored window that is not open in kitty, across all workspaces.

    Each item: {"ws_id", "ws_label", "ws_open", "tab_label", "win_id", "win_label", "cwd"}.
    """
    out: list[dict[str, Any]] = []
    for ws in storage.list_all():
        open_map = kc.open_window_map(state, ws.id)
        for tab in ws.tabs:
            for win in tab.windows:
                if win.id not in open_map:
                    out.append(
                        {
                            "ws_id": ws.id,
                            "ws_label": ws.label,
                            "ws_open": bool(open_map),
                            "tab_label": tab.label,
                            "win_id": win.id,
                            "win_label": win.label,
                            "cwd": win.cwd,
                        }
                    )
    return out


def prune_window(ws_id: str, win_id: str) -> None:
    """Drop a detached window for good: end its zmx session and remove it from the store.

    Refuses an open window: close it first. The workspace itself is kept, even if this
    was its last window (an empty workspace is valid, as with Rex's empty sessions).
    """
    state = kr.ls()
    if win_id in kc.open_window_map(state, ws_id):
        raise RuntimeError("that window is open; close it first")
    ws = storage.load(ws_id)
    if ws is None:
        raise KeyError(ws_id)
    if not ops.remove_window(ws, win_id):
        raise KeyError(win_id)
    storage.save(ws)
    _kill_zmx(win_id)


def mark_closed(ws_id: str, win_id: str) -> bool:
    """Called by the watcher when a kitty window closes: the window is detached, not killed."""
    ws = storage.load(ws_id)
    if ws is None or ops.find_window(ws, win_id) is None:
        return False  # already removed (killed) or unknown
    ops.set_state(ws, win_id, STATE_DETACHED)
    storage.save(ws)
    return True
