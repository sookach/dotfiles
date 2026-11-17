"""Kitty watcher: mark a workspace window detached when its kitty window closes. See DESIGN.md.

Loaded with `watcher workspace_watcher.py` in kitty.conf. Runs inside kitty's
process, so it imports only the pure `workspaces` package. Errors are printed
to kitty's stderr and otherwise ignored, so they never break a window.
"""

from __future__ import annotations

import os
import sys
from typing import Any

# Kitty loads watchers with exec(), so __file__ is undefined. Use the config dir.
_HERE = os.environ.get("KITTY_CONFIG_DIRECTORY") or os.path.expanduser(
    "~/.config/kitty"
)
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

from workspaces import actions, kitty_cmd  # noqa: E402


def on_close(boss: Any, window: Any, data: dict[str, Any]) -> None:
    try:
        user_vars = getattr(window, "user_vars", None) or {}
        ws_id = user_vars.get(kitty_cmd.VAR_WORKSPACE)
        win_id = user_vars.get(kitty_cmd.VAR_WINDOW)
        if ws_id and win_id:
            actions.mark_closed(ws_id, win_id)
    except Exception as e:
        print(f"workspace_watcher on_close: {e}", file=sys.stderr)

