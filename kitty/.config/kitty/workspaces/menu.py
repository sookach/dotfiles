"""The picker's command menu: every workspace command, in one place. See DESIGN.md.

Each command is a function taking a UI and a Ctx. The UI (choose / ask / confirm / say) is
injected, so the logic is testable without a terminal. The real UI is default_ui().

Base menu commands: select, new_workspace, rename_workspace, kill_workspace, new_tab,
split_right, split_down, rename_tab, kill_window, close_workspace_window, detached.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

from . import actions, storage
from . import kitty_remote as kr
from .choose import choose as terminal_choose
from .models import STATE_DETACHED, Workspace


@dataclass
class UI:
    choose: Callable  # (items, prompt, expect=()) -> (key, index) | None
    ask: Callable  # (prompt) -> str | None; "" for a blank answer, None if cancelled
    confirm: Callable  # (prompt) -> bool
    say: Callable  # (message) -> None


@dataclass
class Ctx:
    anchor: int | None  # the window the user came from
    self_id: int | None  # the picker's own window (closed when a command finishes)

    def require_anchor(self) -> int:
        if self.anchor is None:
            raise RuntimeError("no window to act on")
        return self.anchor


def default_ui() -> UI:
    def ask(prompt: str) -> str | None:
        try:
            return input(prompt).strip()
        except EOFError:
            return None

    def confirm(prompt: str) -> bool:
        return (ask(f"{prompt} [y/N] ") or "").lower() == "y"

    def say(message: str) -> None:
        print(message)

    return UI(choose=terminal_choose, ask=ask, confirm=confirm, say=say)


def ws_label(ws: Workspace) -> str:
    windows = [w for t in ws.tabs for w in t.windows]
    detached = sum(1 for w in windows if w.state == STATE_DETACHED)
    return f"{ws.label}  ({len(ws.tabs)} tabs, {len(windows)} windows, {detached} detached)"


def _pick_workspace(ui: UI, prompt: str) -> Workspace | None:
    workspaces = storage.list_all()
    if not workspaces:
        ui.say("No workspaces yet.")
        return None
    picked = ui.choose([ws_label(w) for w in workspaces], prompt)
    return None if picked is None else workspaces[picked[1]]


# ---- workspace commands -------------------------------------------------------


def cmd_select(ui: UI, ctx: Ctx) -> None:
    workspaces = storage.list_all()
    picked = ui.choose(["New workspace"] + [ws_label(w) for w in workspaces], "workspace> ")
    if picked is None:
        return
    if picked[1] == 0:
        return cmd_new_workspace(ui, ctx)
    ws = workspaces[picked[1] - 1]
    result = kr.open_workspace(ws, ctx.anchor, close_window=ctx.self_id)
    ui.say(f"{result}: {ws.label}")


def cmd_new_workspace(ui: UI, ctx: Ctx) -> None:
    name = ui.ask("Workspace name (blank for a default): ")
    if name is None:
        return
    ws = actions.create_workspace(name or None)
    result = kr.open_workspace(ws, ctx.anchor, close_window=ctx.self_id)
    ui.say(f"{result}: {ws.label}")


def cmd_rename_workspace(ui: UI, ctx: Ctx) -> None:
    ws = _pick_workspace(ui, "rename> ")
    if ws is None:
        return
    name = ui.ask(f"New name for '{ws.label}': ")
    if name:
        actions.rename_workspace(ws.id, name)
        ui.say(f"renamed to {name}")


def cmd_kill_workspace(ui: UI, ctx: Ctx) -> None:
    ws = _pick_workspace(ui, "kill> ")
    if ws is None:
        return
    windows = sum(len(t.windows) for t in ws.tabs)
    if ui.confirm(f"Kill '{ws.label}' and end its {windows} zmx session(s)?"):
        actions.kill_workspace(ws.id, ctx.anchor)


# ---- window and tab commands (act on the window the user came from) -------------


def cmd_new_tab(ui: UI, ctx: Ctx) -> None:
    actions.new_window(ctx.require_anchor(), where="tab")


def cmd_split_right(ui: UI, ctx: Ctx) -> None:
    actions.new_window(ctx.require_anchor(), where="vsplit")


def cmd_split_down(ui: UI, ctx: Ctx) -> None:
    actions.new_window(ctx.require_anchor(), where="hsplit")


def cmd_rename_tab(ui: UI, ctx: Ctx) -> None:
    name = ui.ask("Tab name: ")
    if name:
        actions.rename_tab(ctx.require_anchor(), name)


def cmd_kill_window(ui: UI, ctx: Ctx) -> None:
    actions.kill_window(ctx.require_anchor())


def cmd_close_workspace_window(ui: UI, ctx: Ctx) -> None:
    closed = actions.close_workspace_window(ctx.require_anchor())
    if closed == 0:
        ui.say("This window is not in a workspace.")


# ---- detached windows ---------------------------------------------------------


def cmd_detached(ui: UI, ctx: Ctx) -> None:
    items = actions.detached_windows(kr.ls())
    if not items:
        ui.say("No detached windows.")
        return
    labels = [
        f"{it['ws_label']} / {it['tab_label']} / {it['win_id']}"
        + ("" if it["ws_open"] else "  [workspace closed]")
        for it in items
    ]
    picked = ui.choose(labels, "detached> ", expect=("ctrl-x", "f3"))
    if picked is None:
        return
    key, index = picked
    if key == "f3":
        if ui.confirm(f"End the zmx sessions of all {len(items)} detached window(s)?"):
            _prune_all(ui, items)
        return
    it = items[index]
    if key == "ctrl-x":
        if ui.confirm(f"End the zmx session for {it['win_id']}?"):
            actions.prune_window(it["ws_id"], it["win_id"])
            ui.say("pruned")
        return
    if not it["ws_open"]:
        ui.say(f"'{it['ws_label']}' isn't open. Select it first, then reattach.")
        return
    kr.reattach_window(it["ws_id"], it["win_id"])
    ui.say(f"reattached into {it['ws_label']}")


def _prune_all(ui: UI, items: list[dict]) -> None:
    failed = []
    for it in items:
        try:
            actions.prune_window(it["ws_id"], it["win_id"])
        except Exception as e:
            failed.append(f"{it['win_id']}: {e}")
    ui.say(f"pruned {len(items) - len(failed)} of {len(items)}")
    for line in failed:
        ui.say(f"  failed {line}")


# ---- the menu -----------------------------------------------------------------

COMMANDS: dict[str, tuple[str, Callable[[UI, Ctx], None]]] = {
    "select": ("Select workspace", cmd_select),
    "new_workspace": ("New workspace", cmd_new_workspace),
    "rename_workspace": ("Rename workspace", cmd_rename_workspace),
    "kill_workspace": ("Kill workspace", cmd_kill_workspace),
    "new_tab": ("New tab", cmd_new_tab),
    "split_right": ("Split right", cmd_split_right),
    "split_down": ("Split down", cmd_split_down),
    "rename_tab": ("Rename tab", cmd_rename_tab),
    "kill_window": ("Kill this window", cmd_kill_window),
    "close_workspace_window": ("Close workspace window", cmd_close_workspace_window),
    "detached": ("Detached windows (reattach or prune)", cmd_detached),
}
BASE_MENU = [
    "select",
    "new_workspace",
    "rename_workspace",
    "kill_workspace",
    "new_tab",
    "split_right",
    "split_down",
    "rename_tab",
    "kill_window",
    "close_workspace_window",
    "detached",
]


def run(command: str | None, ctx: Ctx, ui: UI) -> bool:
    """Run one command, or the base menu when `command` is None. Returns False on a failure."""
    try:
        if command is None:
            picked = ui.choose([COMMANDS[c][0] for c in BASE_MENU], "command> ")
            if picked is None:
                return True
            command = BASE_MENU[picked[1]]
        if command not in COMMANDS:
            ui.say(f"Unknown command {command!r}. Known: {', '.join(COMMANDS)}.")
            return False
        COMMANDS[command][1](ui, ctx)
        return True
    except Exception as e:
        ui.say(f"Failed: {e}")
        return False
