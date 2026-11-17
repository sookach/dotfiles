"""ctrl+s, shift+t: rename this window's tab. The name is saved, so it survives a restart. See DESIGN.md."""

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
        name = input("Tab name: ").strip()
        if name:
            actions.rename_tab(anchor, name)
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
