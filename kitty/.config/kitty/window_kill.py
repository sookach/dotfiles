"""cmd+shift+w: remove this window from its workspace, kill its zmx session, close it. See DESIGN.md."""

from __future__ import annotations

import os
import sys

# Kitty runs kitten sources with exec(), so __file__ is undefined. Use the config dir.
_HERE = os.environ.get("KITTY_CONFIG_DIRECTORY") or os.path.expanduser(
    "~/.config/kitty"
)
if _HERE not in sys.path:  # kittens may not have their own dir on sys.path
    sys.path.insert(0, _HERE)

from workspaces import actions, kitty_remote  # noqa: E402


def main(args: list[str]) -> str:
    win = kitty_remote.anchor_id()
    if win is None:
        print("Not running inside a kitty window.")
        return ""
    try:
        actions.kill_window(win)
    except Exception as e:
        print(f"kill failed: {e}")
        try:
            input("\nPress Enter to close.")
        except EOFError:
            pass
    return ""


if __name__ == "__main__":
    main(sys.argv[1:])

