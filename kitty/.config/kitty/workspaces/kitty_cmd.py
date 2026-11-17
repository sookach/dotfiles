"""Pure helpers for talking to kitty: argv builders and readers of `kitten @ ls` JSON.

Nothing here runs a process except resolving binary paths. That is what makes it
testable without kitty. The side-effecting code lives in kitty_remote.py.
"""

from __future__ import annotations

import os
import shutil
from typing import Any

KITTEN_FALLBACK = "/Applications/kitty.app/Contents/MacOS/kitten"
ZMX_FALLBACK = "/opt/homebrew/bin/zmx"
VAR_WORKSPACE = "kitty_workspace"
VAR_WINDOW = "kitty_window"
PLACEMENTS = ("tab", "vsplit", "hsplit")


# ---- binaries -----------------------------------------------------------------


def kitten_bin() -> str:
    # Kitten children may not inherit the interactive PATH; prefer absolute paths.
    return shutil.which("kitten") or KITTEN_FALLBACK


def zmx_bin() -> str:
    return shutil.which("zmx") or ZMX_FALLBACK


# ---- argv builders ------------------------------------------------------------


def zmx_attach_argv(win_id: str) -> list[str]:
    return [zmx_bin(), "attach", win_id]


def launch_argv(
    *,
    kind: str,  # "os-window" | "tab" | "window"
    cmd: list[str],
    cwd: str | None = None,
    match: str | None = None,  # e.g. "id:12"
    location: str | None = None,
    tab_title: str | None = None,
) -> list[str]:
    argv = ["launch", f"--type={kind}"]
    if match:
        argv += ["--match", match]
    if location:
        argv += ["--location", location]
    if tab_title:
        argv += ["--tab-title", tab_title]
    if cwd and os.path.isdir(os.path.expanduser(cwd)):
        argv += ["--cwd", os.path.expanduser(cwd)]
    return argv + cmd


def set_vars_argv(kitty_win_id: int, ws_id: str, win_id: str) -> list[str]:
    return [
        "set-user-vars",
        "--match",
        f"id:{kitty_win_id}",
        f"{VAR_WORKSPACE}={ws_id}",
        f"{VAR_WINDOW}={win_id}",
    ]


def focus_argv(ws_id: str) -> list[str]:
    return ["focus-window", "--match", f"var:{VAR_WORKSPACE}={ws_id}"]


def close_argv(kitty_win_id: int) -> list[str]:
    return ["close-window", "--match", f"id:{kitty_win_id}"]


def placement_from_args(args: list[str]) -> str:
    """Kitty passes the kitten's own path as args[0], so search for a known placement word."""
    return next((a for a in args if a in PLACEMENTS), "tab")


# ---- readers of `kitten @ ls` output -------------------------------------------


def windows(state: list[dict[str, Any]]):
    """Every kitty window in every OS window and tab."""
    for osw in state:
        for tab in osw.get("tabs", []):
            yield from tab.get("windows", [])


def window_var(state: list[dict[str, Any]], kitty_win_id: int | None, key: str) -> str | None:
    """A user variable of one kitty window, or None if the window or variable is missing."""
    for w in windows(state):
        if w.get("id") == kitty_win_id:
            return (w.get("user_vars") or {}).get(key)
    return None


def current_workspace_id(state: list[dict[str, Any]], kitty_win_id: int | None) -> str | None:
    """The workspace a kitty window belongs to, or None."""
    return window_var(state, kitty_win_id, VAR_WORKSPACE)


def window_cwd(state: list[dict[str, Any]], kitty_win_id: int) -> str | None:
    for w in windows(state):
        if w.get("id") == kitty_win_id:
            return w.get("cwd") or None
    return None


def windows_of_workspace(state: list[dict[str, Any]], ws_id: str) -> list[dict[str, Any]]:
    return [
        w
        for w in windows(state)
        if (w.get("user_vars") or {}).get(VAR_WORKSPACE) == ws_id
    ]


def open_window_map(state: list[dict[str, Any]], ws_id: str) -> dict[str, int]:
    """stored win_id -> kitty window id, for this workspace's windows that are open in kitty."""
    out: dict[str, int] = {}
    for w in windows_of_workspace(state, ws_id):
        win_id = (w.get("user_vars") or {}).get(VAR_WINDOW)
        if win_id:
            out[win_id] = w["id"]
    return out


def tab_windows(state: list[dict[str, Any]], kitty_win_id: int | None) -> list[dict[str, Any]]:
    """The windows of the tab containing `kitty_win_id` (empty if not found)."""
    for osw in state:
        for tab in osw.get("tabs", []):
            wins = tab.get("windows", [])
            if any(w.get("id") == kitty_win_id for w in wins):
                return wins
    return []


def os_window_windows(state: list[dict[str, Any]], kitty_win_id: int) -> list[dict[str, Any]]:
    """Every kitty window in the same OS window as `kitty_win_id`."""
    for osw in state:
        wins = [w for tab in osw.get("tabs", []) for w in tab.get("windows", [])]
        if any(w.get("id") == kitty_win_id for w in wins):
            return wins
    return []
