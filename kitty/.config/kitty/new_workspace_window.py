"""cmd+n: new OS window with a new workspace. See DESIGN.md."""

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
    # The picker runs as the new OS window's only window; choosing a workspace (or the
    # "new workspace" entry) opens it there, so cmd+n never leaves an empty window behind.
    try:
        kitty_remote.launch_picker_os_window()
    except Exception as e:
        print(f"new window failed: {e}")
        try:
            input("\nPress Enter to close.")
        except EOFError:
            pass
    return ""


if __name__ == "__main__":
    main(sys.argv[1:])

