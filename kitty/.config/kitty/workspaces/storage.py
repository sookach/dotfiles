"""On-disk store: one JSON file per workspace. Pure Python, no kitty imports. See DESIGN.md.

KITTY_WORKSPACES_DIR overrides the directory (used by the tests).
"""

from __future__ import annotations

import json
import os
import re
from dataclasses import asdict
from pathlib import Path

from .models import SCHEMA_VERSION, Tab, Window, Workspace

DEFAULT_DIR = Path("~/.local/share/kitty-workspaces").expanduser()
_ID = re.compile(r"^(ws|tab|win)-[0-9a-f]{8}$")


def store_dir() -> Path:
    override = os.environ.get("KITTY_WORKSPACES_DIR")
    return Path(override).expanduser() if override else DEFAULT_DIR


def validate_id(value: str) -> str:
    # Workspace IDs become filenames and window IDs become zmx session names.
    if not _ID.match(value):
        raise ValueError(f"invalid id {value!r}")
    return value


def _path_for(ws_id: str) -> Path:
    return store_dir() / f"{validate_id(ws_id)}.json"


def _from_dict(d: dict) -> Workspace:
    version = d.get("version", SCHEMA_VERSION)
    if version != SCHEMA_VERSION:
        raise ValueError(f"unsupported workspace schema version {version}")
    return Workspace(
        id=d["id"],
        label=d["label"],
        version=version,
        tabs=[
            Tab(
                id=t["id"],
                label=t["label"],
                windows=[
                    Window(
                        id=w["id"],
                        label=w["label"],
                        cwd=w.get("cwd"),
                        state=w.get("state", "detached"),
                        placement=w.get("placement"),
                    )
                    for w in t.get("windows", [])
                ],
            )
            for t in d.get("tabs", [])
        ],
    )


def load(ws_id: str) -> Workspace | None:
    path = _path_for(ws_id)
    if not path.exists():
        return None
    with path.open() as f:
        return _from_dict(json.load(f))


def list_all() -> list[Workspace]:
    d = store_dir()
    if not d.is_dir():
        return []
    out = []
    for path in sorted(d.glob("ws-*.json")):
        with path.open() as f:
            out.append(_from_dict(json.load(f)))
    return sorted(out, key=lambda w: w.label.lower())


def save(ws: Workspace) -> Path:
    path = _path_for(ws.id)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".json.tmp")
    with tmp.open("w") as f:
        json.dump(asdict(ws), f, indent=2)
        f.write("\n")
    os.replace(tmp, path)  # atomic: a crash never leaves a half-written file
    return path


OPEN_FILE = "_open.json"  # not matched by list_all(), which reads ws-*.json


def load_open_ids() -> list[str]:
    """Workspaces that were open when last changed, in the order they were opened (for startup restore)."""
    path = store_dir() / OPEN_FILE
    if not path.exists():
        return []
    with path.open() as f:
        return [validate_id(x) for x in json.load(f)]


def _save_open_ids(ids: list[str]) -> None:
    path = store_dir() / OPEN_FILE
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".json.tmp")
    with tmp.open("w") as f:
        json.dump(ids, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)


def add_open_id(ws_id: str) -> None:
    ids = load_open_ids()
    if ws_id not in ids:
        ids.append(validate_id(ws_id))
        _save_open_ids(ids)


def remove_open_id(ws_id: str) -> None:
    ids = load_open_ids()
    if ws_id in ids:
        ids.remove(ws_id)
        _save_open_ids(ids)


def delete(ws_id: str) -> bool:
    path = _path_for(ws_id)
    if path.exists():
        path.unlink()
        return True
    return False

