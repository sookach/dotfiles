"""Pure operations on a Workspace. Every mutation goes through here so it is unit-tested."""

from __future__ import annotations

import secrets

from .models import STATE_DETACHED, STATE_OPEN, Tab, Window, Workspace


def new_id(prefix: str) -> str:
    return f"{prefix}-{secrets.token_hex(4)}"


def new_workspace(label: str) -> Workspace:
    return Workspace(id=new_id("ws"), label=label)


def find_window(ws: Workspace, win_id: str) -> tuple[Tab, Window] | None:
    for tab in ws.tabs:
        for win in tab.windows:
            if win.id == win_id:
                return tab, win
    return None


def add_window(
    ws: Workspace, label: str, cwd: str | None, tab_id: str | None = None
) -> Window:
    """Add a window. With tab_id=None, starts a new tab for it. Returns the new window."""
    win = Window(id=new_id("win"), label=label, cwd=cwd, state=STATE_OPEN)
    if tab_id is None:
        ws.tabs.append(Tab(id=new_id("tab"), label=label, windows=[win]))
        return win
    for tab in ws.tabs:
        if tab.id == tab_id:
            tab.windows.append(win)
            return win
    raise KeyError(f"no tab {tab_id}")


def set_state(ws: Workspace, win_id: str, state: str) -> bool:
    found = find_window(ws, win_id)
    if found is None:
        return False
    found[1].state = state
    return True


def remove_window(ws: Workspace, win_id: str) -> bool:
    """Remove a window; drops its tab too if that was the tab's last window."""
    for tab in ws.tabs:
        for i, win in enumerate(tab.windows):
            if win.id == win_id:
                del tab.windows[i]
                if not tab.windows:
                    ws.tabs.remove(tab)
                return True
    return False


def rename(ws: Workspace, label: str) -> None:
    ws.label = label


def tab_for_window(ws: Workspace, win_id: str) -> Tab | None:
    found = find_window(ws, win_id)
    return found[0] if found else None

