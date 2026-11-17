"""Live self-test for kitty-workspaces. Run it from a kitty window:

    kitten ~/.config/kitty/workspace_selftest.py

It creates one throwaway workspace in the real store, drives the real flows against
this kitty, checks each result, and removes everything it made (even on failure).
It uses the real store on purpose: the watcher runs inside kitty and writes to the
real store, so an isolated store would hide the check that matters most.

Needs the watcher loaded (kitty.conf `watcher workspace_watcher.py`) for the detach step.
"""

from __future__ import annotations

import os
import subprocess
import sys
import time

_HERE = os.environ.get("KITTY_CONFIG_DIRECTORY") or os.path.expanduser("~/.config/kitty")
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

from workspaces import actions, kitty_cmd as kc, kitty_remote as kr, ops, storage  # noqa: E402
from workspaces.kitten_util import quiet  # noqa: E402
from workspaces.models import STATE_DETACHED, STATE_OPEN  # noqa: E402

RESULTS: list[tuple[str, bool]] = []


def check(name: str, ok: bool, detail: str = "") -> None:
    RESULTS.append((name, bool(ok)))
    suffix = "" if ok or not detail else f"   ({detail})"
    print(f"{'PASS' if ok else 'FAIL'}  {name}{suffix}")


def wait_for(pred, timeout: float = 8.0) -> bool:
    end = time.time() + timeout
    while time.time() < end:
        if pred():
            return True
        time.sleep(0.25)
    return bool(pred())


def ws_windows(ws_id: str) -> list[dict]:
    return kc.windows_of_workspace(kr.ls(), ws_id)


def zmx_alive(win_id: str) -> bool:
    out = subprocess.run([kc.zmx_bin(), "list", "--short"], capture_output=True, text=True).stdout
    return any(win_id in line for line in out.splitlines())


def store_states(ws_id: str) -> list[str]:
    ws = storage.load(ws_id)
    return [w.state for t in ws.tabs for w in t.windows] if ws else []


def run() -> None:
    me = kr.self_window_id()
    check("kitten @ can reach kitty", bool(kr.ls()))
    check("anchor resolves to this window", kr.anchor_id() == me, f"anchor={kr.anchor_id()} self={me}")

    ws = actions.create_workspace()
    ops.rename(ws, f"selftest-{os.getpid()}")
    storage.save(ws)
    try:
        # 1. open: tabs appear in this OS window, tagged with user variables
        result = kr.open_workspace(ws, anchor=None, new_os_window=True)
        check("open: returns 'opened'", result == "opened", result)
        check("open: windows appear with kitty_workspace user var", wait_for(lambda: len(ws_windows(ws.id)) >= 1))
        first = ws_windows(ws.id)[0]["id"]
        check("open: store marks the window open", store_states(ws.id) == [STATE_OPEN], str(store_states(ws.id)))

        # 2. split and tab from the open window (ctrl+s v, cmd+t)
        actions.new_window(first, where="vsplit")
        actions.new_window(first, where="tab")
        check("split+tab: three windows in the workspace", wait_for(lambda: len(ws_windows(ws.id)) == 3),
              f"have {len(ws_windows(ws.id))}")

        # 3. detach: closing a window (cmd+w) must mark it detached via the watcher
        target = ws_windows(ws.id)[-1]
        target_win = target["user_vars"]["kitty_window"]
        kr.run_close(target["id"])
        check("detach: watcher marks the closed window detached",
              wait_for(lambda: STATE_DETACHED in store_states(ws.id)),
              f"states={store_states(ws.id)}")
        check("detach: zmx session survives the window closing", zmx_alive(target_win))

        # 4. reattach: cmd+k on an open workspace brings the detached window back
        result = kr.open_workspace(storage.load(ws.id), anchor=None, new_os_window=True)
        check("open of an open workspace: returns 'focused'", result == "focused", result)
        check("open of an open workspace: restores nothing", len(ws_windows(ws.id)) == 2,
              f"have {len(ws_windows(ws.id))}")
        result = kr.reattach_window(ws.id, target_win)
        check("reattach: returns 'reattached'", result == "reattached", result)
        check("reattach: the chosen window is back", wait_for(lambda: len(ws_windows(ws.id)) == 3))

        # 5. close workspace window (cmd+shift+w): detaches all, leaves the store entry
        anchor_win = ws_windows(ws.id)[0]["id"]
        closed = actions.close_workspace_window(anchor_win)
        check("close workspace window: closes the workspace's three windows", closed == 3, f"closed={closed}")
        check("close workspace window: all detached in store",
              wait_for(lambda: store_states(ws.id) and all(s == STATE_DETACHED for s in store_states(ws.id))),
              str(store_states(ws.id)))
        check("close workspace window: workspace kept in store", storage.load(ws.id) is not None)

        # 6. reopen, then kill: zmx sessions end, windows close, store entry deleted
        kr.open_workspace(storage.load(ws.id), anchor=None, new_os_window=True)
        check("reopen after close: three windows", wait_for(lambda: len(ws_windows(ws.id)) == 3))
        ids = [w["user_vars"]["kitty_window"] for w in ws_windows(ws.id)]
        n = actions.kill_workspace(ws.id, anchor=me)
        check("kill: reports three windows", n == 3, f"n={n}")
        check("kill: kitty windows closed", wait_for(lambda: not ws_windows(ws.id)))
        check("kill: zmx sessions ended", wait_for(lambda: not any(zmx_alive(i) for i in ids)))
        check("kill: store entry deleted", storage.load(ws.id) is None)
    finally:
        # Cleanup, whatever happened above.
        if storage.load(ws.id) is not None:
            try:
                actions.kill_workspace(ws.id, anchor=me)
                print("cleanup: killed leftover selftest workspace")
            except Exception as e:
                print(f"cleanup failed, remove by hand: {ws.id} ({e})")


def main(args: list[str]) -> str:
    try:
        run()
    except Exception as e:
        check("selftest ran to completion", False, repr(e))
    passed = sum(ok for _, ok in RESULTS)
    print(f"\n{passed}/{len(RESULTS)} checks passed")
    if passed != len(RESULTS):
        print("Failed checks above. Paste this output to the developer.")
    try:
        input("\nPress Enter to close.")
    except EOFError:
        pass
    return ""


main = quiet(main)


if __name__ == "__main__":
    main(sys.argv[1:])
