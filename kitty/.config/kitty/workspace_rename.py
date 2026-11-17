"""ctrl+s, w, r: rename the workspace this window belongs to (label only). See DESIGN.md."""

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
from workspaces.kitten_util import quiet  # noqa: E402


def main(args: list[str]) -> str:
    try:
        state = kitty_remote.ls()
        ws_id = kitty_cmd.current_workspace_id(state, kitty_remote.anchor_id())
        if not ws_id:
            print("This window is not in a workspace.")
            input("\nPress Enter to close.")
            return ""
        new = input("New workspace name: ").strip()
        if new:
            actions.rename_workspace(ws_id, new)
            print(f"Renamed to {new}")
            input("\nPress Enter to close.")
    except EOFError:
        pass
    except Exception as e:
        print(f"rename failed: {e}")
        try:
            input("\nPress Enter to close.")
        except EOFError:
            pass
    return ""


main = quiet(main)


if __name__ == "__main__":
    main(sys.argv[1:])

