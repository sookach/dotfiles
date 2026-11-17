"""The picker: the workspace command menu. See DESIGN.md and workspaces/menu.py.

Run with no arguments for the base menu, or with `--command <name>` to run one command
directly (the command palette and cmd+k use that). `--anchor <id>` is the window the user came
from. The picker runs in its own tab (full window size, not zmx-backed) and ends when the
command does.

  --command select              pick a workspace to open (cmd+k, cmd+n)
  --command detached            detached windows: Enter reattaches, ctrl-x prunes, F3 prunes all
  --command kill_workspace      pick a workspace to kill
  --command <name>              any command in workspaces/menu.py COMMANDS
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

from workspaces import kitty_remote, menu  # noqa: E402
from workspaces.kitten_util import quiet  # noqa: E402


def _arg(args: list[str], name: str) -> str | None:
    for i, a in enumerate(args):
        if a == name and i + 1 < len(args):
            return args[i + 1]
    return None


def _anchor(args: list[str]) -> int | None:
    raw = _arg(args, "--anchor")
    if raw is not None and raw.isdigit():
        return int(raw)
    return kitty_remote.anchor_id()


def main(args: list[str]) -> str:
    ctx = menu.Ctx(anchor=_anchor(args), self_id=kitty_remote.self_window_id())
    ok = menu.run(_arg(args, "--command"), ctx, menu.default_ui())
    if not ok:  # keep the message on screen; the tab would otherwise vanish
        try:
            input("\nPress Enter to close.")
        except EOFError:
            pass
    return ""


main = quiet(main)


if __name__ == "__main__":
    main(sys.argv[1:])
