"""cmd+k (over the current window) and cmd+n (its own new OS window): pick a workspace and open it.

Entries:
  <number> or <name>   open it (or focus it, if it is already open)
  n                    create an empty workspace with one zmx window and open it
  x <number>           kill a workspace (its zmx sessions end, its windows close), after confirming
  d                    list detached windows; then "r <n>" reattaches one into its open
                       workspace, and "p <n>" prunes one (ends its zmx session)
See DESIGN.md.
"""

from __future__ import annotations

import os
import sys

# Kitty runs kitten sources with exec(), so __file__ is undefined. Use the config dir.
_HERE = os.environ.get("KITTY_CONFIG_DIRECTORY") or os.path.expanduser(
    "~/.config/kitty"
)
if _HERE not in sys.path:  # kittens may not have their own dir on sys.path
    sys.path.insert(0, _HERE)

from workspaces import actions, kitty_remote, storage  # noqa: E402
from workspaces.models import STATE_DETACHED  # noqa: E402

NEW = "new"


def _pause() -> None:
    try:
        input("\nPress Enter to close.")
    except EOFError:
        pass


def _find(workspaces: list, choice: str):
    if choice.isdigit() and 1 <= int(choice) <= len(workspaces):
        return workspaces[int(choice) - 1]
    matches = [w for w in workspaces if w.label.lower() == choice.lower()]
    return matches[0] if len(matches) == 1 else None


def _kill(workspaces: list, arg: str) -> None:
    ws = _find(workspaces, arg.strip())
    if ws is None:
        print(f"No unique workspace matching {arg.strip()!r}.")
        _pause()
        return
    windows = sum(len(t.windows) for t in ws.tabs)
    answer = (
        input(f"Kill '{ws.label}' and end its {windows} zmx session(s)? [y/N] ")
        .strip()
        .lower()
    )
    if answer != "y":
        return
    try:
        anchor = kitty_remote.anchor_id()
        actions.kill_workspace(ws.id, anchor)
    except Exception as e:
        print(f"Kill failed: {e}")
        _pause()


def _detached_menu() -> None:
    items = actions.detached_windows(kitty_remote.ls())
    if not items:
        print("No detached windows.")
        _pause()
        return
    print("Detached windows\n")
    for i, it in enumerate(items, start=1):
        where = "" if it["ws_open"] else "  [workspace not open]"
        print(f"  {i}. {it['ws_label']} / {it['tab_label']} / {it['win_id']}{where}")
    try:
        choice = input("\nreattach 'r <n>', prune 'p <n>', blank to cancel: ").strip()
    except EOFError:
        return
    parts = choice.split()
    if len(parts) != 2 or parts[0] not in ("r", "p") or not parts[1].isdigit():
        return
    n = int(parts[1])
    if not 1 <= n <= len(items):
        print(f"No detached window {n}.")
        _pause()
        return
    it = items[n - 1]
    try:
        if parts[0] == "r":
            kitty_remote.reattach_window(it["ws_id"], it["win_id"])
            print(f"reattached into {it['ws_label']}")
        else:
            answer = input(f"End the zmx session for {it['win_id']}? [y/N] ").strip().lower()
            if answer == "y":
                actions.prune_window(it["ws_id"], it["win_id"])
                print("pruned")
    except Exception as e:
        print(f"Failed: {e}")
        _pause()


def main(args: list[str]) -> str:
    workspaces = storage.list_all()

    print("Workspaces\n")
    for i, ws in enumerate(workspaces, start=1):
        windows = [w for t in ws.tabs for w in t.windows]
        detached = sum(1 for w in windows if w.state == STATE_DETACHED)
        print(
            f"  {i}. {ws.label}  ({len(ws.tabs)} tabs, {len(windows)} windows, {detached} detached)"
        )
    if not workspaces:
        print("  (none yet)")
    print("  n. New workspace")
    print("  x <number>. Kill a workspace")
    print("  d. Detached windows (reattach or prune)")

    try:
        choice = input("\nOpen (number, name, n, d, or x <number>; blank to cancel): ").strip()
    except EOFError:
        return ""
    if not choice:
        return ""

    if choice.lower() == "d":
        _detached_menu()
        return ""

    if choice.lower().startswith("x "):
        _kill(workspaces, choice[1:])
        return ""

    if choice.lower() in ("n", NEW):
        ws = actions.create_workspace()
    else:
        ws = _find(workspaces, choice)
        if ws is None:
            print(f"No unique workspace matching {choice!r}.")
            _pause()
            return ""

    try:
        anchor = kitty_remote.anchor_id()
        # cmd+n runs this picker as its own window, so anchor == self: an empty placeholder.
        close_anchor = anchor is not None and anchor == kitty_remote.self_window_id()
        result = kitty_remote.open_workspace(ws, anchor, close_anchor=close_anchor)
        print(f"{result}: {ws.label}")
    except Exception as e:  # show the failure; the window would otherwise vanish
        print(f"Failed to open {ws.label}: {e}")
        _pause()
    return ""


if __name__ == "__main__":
    main(sys.argv[1:])
