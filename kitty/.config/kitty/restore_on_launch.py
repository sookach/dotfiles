"""Startup restore (opt-in): reopen the workspaces that were open last time, one OS window each.

Enabled by a `startup_session` line in kitty.conf that runs this kitten. See DESIGN.md.
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

from workspaces import kitty_remote, storage  # noqa: E402
from workspaces.kitten_util import quiet  # noqa: E402


def main(args: list[str]) -> str:
    errors: list[str] = []
    for ws_id in storage.load_open_ids():
        ws = storage.load(ws_id)
        if ws is None:
            continue
        try:
            kitty_remote.open_workspace(ws, anchor=None, new_os_window=True)
        except (
            Exception
        ) as e:  # keep going: one broken workspace should not block the rest
            errors.append(f"{ws.label}: {e}")
    if errors:
        print("Some workspaces failed to restore:")
        for e in errors:
            print(f"  {e}")
        try:
            input("\nPress Enter to close.")
        except EOFError:
            pass
    return ""


main = quiet(main)


if __name__ == "__main__":
    main(sys.argv[1:])

