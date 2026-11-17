"""New zmx-backed window in the current workspace. See DESIGN.md.

Bindings:
    cmd+t       kitten new_window.py
    ctrl+s, v   kitten new_window.py vsplit
    ctrl+s, n   kitten new_window.py hsplit
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

from workspaces import actions, kitty_cmd, kitty_remote  # noqa: E402


def main(args: list[str]) -> str:
    where = kitty_cmd.placement_from_args(args)
    try:
        actions.new_window(kitty_remote.anchor_id(), where=where)
    except Exception as e:
        print(f"new window failed: {e}")
        try:
            input("\nPress Enter to close.")
        except EOFError:
            pass
    return ""


if __name__ == "__main__":
    main(sys.argv[1:])

