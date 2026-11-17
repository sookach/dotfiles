"""Side-effecting kitty operations: everything here runs `kitten @`. See DESIGN.md.

Pure argv builders and state readers live in kitty_cmd.py. The functions here combine
them with `kitten @` calls and with the store to open, reattach, and place workspaces.
"""

from __future__ import annotations

import json
import os
import subprocess
from typing import Any

from . import kitty_cmd as kc
from . import ops, storage
from .models import STATE_DETACHED, STATE_OPEN, Window, Workspace
from .ops import set_state


def _run(args: list[str]) -> str:
    res = subprocess.run([kc.kitten_bin(), "@", *args], capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(
            f"kitten @ {' '.join(args[:2])} failed: {res.stderr.strip() or res.stdout.strip()}"
        )
    return res.stdout


# ---- reading kitty state ------------------------------------------------------


def ls(match: str | None = None) -> list[dict[str, Any]]:
    return json.loads(_run(["ls", *([] if match is None else ["--match", match])]))


def anchor_id() -> int | None:
    """The window the user was in when the kitten was launched.

    A kitten run as an overlay has KITTY_WINDOW_ID set to the overlay. The overlay
    sits in the same tab as the window it covers, so that is the anchor: a window in
    this tab that some overlay is attached to. Otherwise (the kitten runs in a plain
    window, e.g. cmd+n's picker or the self-test) the anchor is the window itself.

    `state:overlay_parent` alone is not enough: it matches windows that have an
    overlay anywhere, not only the one this kitten runs in.
    """
    self_id = self_window_id()
    if self_id is None:
        return None
    try:
        state = ls()
    except RuntimeError:
        return self_id
    tab_ids = {w.get("id") for w in kc.tab_windows(state, self_id)} - {self_id}
    if tab_ids:
        try:
            parents = {w.get("id") for w in kc.windows(ls(match="state:overlay_parent"))}
        except RuntimeError:
            # kitten @ exits non-zero with "No matching windows" when nothing matches.
            parents = set()
        for wid in tab_ids:
            if wid in parents:
                return wid
    return self_id


def self_window_id() -> int | None:
    """The window the kitten process is running in. For an overlay, this is the overlay itself."""
    raw = os.environ.get("KITTY_WINDOW_ID", "")
    return int(raw) if raw.isdigit() else None


def config_dir() -> str:
    return os.environ.get("KITTY_CONFIG_DIRECTORY") or os.path.expanduser("~/.config/kitty")


def launch_picker_os_window() -> int:
    """cmd+n: a new OS window running the picker as its only window (no overlay)."""
    picker = os.path.join(config_dir(), "workspace_picker.py")
    return int(
        _run(["launch", "--type=os-window", kc.kitten_bin(), picker, "--command", "select"]).strip()
    )


# ---- single operations --------------------------------------------------------


def launch(kind: str, cmd: list[str], **kw: Any) -> int:
    """Launch a kitty window or tab running `cmd`. Returns the new kitty window id."""
    return int(_run(kc.launch_argv(kind=kind, cmd=cmd, **kw)).strip())


def run_set_vars(kitty_win_id: int, ws_id: str, win_id: str) -> None:
    _run(kc.set_vars_argv(kitty_win_id, ws_id, win_id))


def run_close(kitty_win_id: int) -> None:
    """Close a window. Already gone is fine: killing its zmx session closes it too."""
    try:
        _run(kc.close_argv(kitty_win_id))
    except RuntimeError as e:
        if "No matching windows" not in str(e):
            raise


def run_set_tab_title(kitty_win_id: int, title: str) -> None:
    _run(["set-tab-title", "--match", f"id:{kitty_win_id}", title])


def run_focus_workspace(ws_id: str) -> None:
    _run(kc.focus_argv(ws_id))


# ---- opening workspaces -------------------------------------------------------


def _launch_win(
    ws: Workspace,
    tab_label: str,
    win: Window,
    kind: str,
    match: str | None,
    location: str | None = None,
) -> int:
    """Launch one stored window as a zmx attach in kitty, tag it, and mark it open."""
    title = tab_label if kind in ("os-window", "tab") else None
    kid = launch(
        kind,
        kc.zmx_attach_argv(win.id),
        match=match,
        location=location,
        cwd=win.cwd,
        tab_title=title,
    )
    run_set_vars(kid, ws.id, win.id)
    set_state(ws, win.id, STATE_OPEN)
    return kid


def reattach_window(ws_id: str, win_id: str) -> str:
    """Put one detached window back in its workspace's open OS window.

    It goes beside a window of its own tab if one is open, otherwise as a new tab.
    Only works for a workspace that is open somewhere (cmd+k opens a closed one).
    """
    state = ls()
    open_map = kc.open_window_map(state, ws_id)
    if not open_map:
        raise RuntimeError("the workspace isn't open; open it from cmd+k first")
    if win_id in open_map:
        raise RuntimeError("that window is already open")
    ws = storage.load(ws_id)
    if ws is None:
        raise KeyError(ws_id)
    found = ops.find_window(ws, win_id)
    if found is None:
        raise KeyError(win_id)
    tab, win = found
    beside = [open_map[w.id] for w in tab.windows if w.id in open_map]
    if beside:
        _launch_win(ws, tab.label, win, "window", f"id:{beside[0]}", location=win.placement or "vsplit")
    else:
        _launch_win(ws, tab.label, win, "tab", f"id:{next(iter(open_map.values()))}")
    storage.save(ws)
    return "reattached"


def open_workspace(
    ws: Workspace,
    anchor: int | None,
    close_anchor: bool = False,
    new_os_window: bool = False,
    close_window: int | None = None,
) -> str:
    """Open `ws`. Returns 'opened' or 'focused'.

    - Already open somewhere: focus it. Its detached windows are not restored here;
      use reattach_window to bring one back.
    - Otherwise open its tabs in the anchor's OS window (or a new OS window when
      new_os_window is set, used by startup restore). If the anchor belonged to
      another workspace, that workspace is switched out: its windows are marked
      detached and closed (zmx sessions keep running). The anchor is closed last,
      because the picker overlay runs over it.
    - close_anchor: the anchor is the picker's own window (cmd+n), an empty placeholder;
      it is closed once something has opened in its place.
    """
    state = ls()
    if not any(tab.windows for tab in ws.tabs):
        ops.add_window(ws, label="shell", cwd=None)  # emptied workspace: give it a shell

    if kc.windows_of_workspace(state, ws.id):
        run_focus_workspace(ws.id)
        if close_anchor and anchor is not None:
            run_close(anchor)
        if close_window is not None:
            run_close(close_window)
        return "focused"

    if anchor is None and not new_os_window:
        raise RuntimeError("no window to open the workspace into")

    old_ws_id = kc.current_workspace_id(state, anchor) if anchor is not None else None
    # Only this OS window's windows of the old workspace are switched out. Its windows
    # in other OS windows are left alone.
    old_windows = (
        [
            w
            for w in kc.os_window_windows(state, anchor)
            if (w.get("user_vars") or {}).get(kc.VAR_WORKSPACE) == old_ws_id
        ]
        if old_ws_id and old_ws_id != ws.id and anchor is not None
        else []
    )

    launched = 0
    os_anchor: int | None = None
    for tab in ws.tabs:
        tab_anchor: int | None = None
        for win in tab.windows:
            if tab_anchor is None:
                if new_os_window and os_anchor is None:
                    kid = _launch_win(ws, tab.label, win, "os-window", None)
                    os_anchor = kid
                else:
                    target = os_anchor if os_anchor is not None else anchor
                    kid = _launch_win(ws, tab.label, win, "tab", f"id:{target}")
                tab_anchor = kid
            else:
                kid = _launch_win(
                    ws, tab.label, win, "window", f"id:{tab_anchor}", location=win.placement or "vsplit"
                )
            launched += 1
    storage.save(ws)
    storage.add_open_id(ws.id)

    if old_ws_id and old_windows:
        old = storage.load(old_ws_id)
        if old is not None:
            for kw in old_windows:
                win_id = (kw.get("user_vars") or {}).get(kc.VAR_WINDOW)
                if win_id:
                    set_state(old, win_id, STATE_DETACHED)
            storage.save(old)
        if len(old_windows) == len(kc.windows_of_workspace(state, old_ws_id)):
            storage.remove_open_id(old_ws_id)  # nothing of it is left open anywhere
        for kw in sorted(old_windows, key=lambda w: w.get("id") == anchor):
            run_close(kw["id"])
    # Only give up the placeholder once something actually opened in its place.
    if (
        close_anchor
        and launched
        and anchor is not None
        and not any(kw.get("id") == anchor for kw in old_windows)
    ):
        run_close(anchor)
    # close_window is the picker's own window. Closing it comes last: it ends the picker.
    if close_window is not None and launched:
        run_close(close_window)
    return "opened"
