"""cmd+shift+w: close this workspace's windows in this OS window (detached, not killed). See DESIGN.md."""

from __future__ import annotations

import os
import sys

# Kitty runs kitten sources with exec(), so __file__ is undefined. Use the config dir.
_HERE = os.environ.get("KITTY_CONFIG_DIRECTORY") or os.path.expanduser("~/.config/kitty")
if _HERE not in sys.path:  # kittens may not have their own dir on sys.path
    sys.path.insert(0, _HERE)

from workspaces import actions, kitty_remote  # noqa: E402
from workspaces.kitten_util import quiet  # noqa: E402


def main(args: list[str]) -> str:
    try:
        anchor = kitty_remote.anchor_id()
        if anchor is None:
            return ""
        if actions.close_workspace_window(anchor) == 0:
            print("This window is not in a workspace.")
            input("\nPress Enter to close.")
    except EOFError:
        pass
    except Exception as e:
        print(f"close failed: {e}")
        try:
            input("\nPress Enter to close.")
        except EOFError:
            pass
    return ""


main = quiet(main)


if __name__ == "__main__":
    main(sys.argv[1:])
