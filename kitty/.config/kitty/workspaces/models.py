"""Data model for kitty workspaces. See DESIGN.md. No kitty imports."""

from __future__ import annotations

from dataclasses import dataclass, field

SCHEMA_VERSION = 1
STATE_OPEN = "open"
STATE_DETACHED = "detached"


@dataclass
class Window:
    id: str
    label: str
    cwd: str | None = None
    state: str = STATE_DETACHED


@dataclass
class Tab:
    id: str
    label: str
    windows: list[Window] = field(default_factory=list)

    @property
    def detached(self) -> bool:
        return all(w.state == STATE_DETACHED for w in self.windows)


@dataclass
class Workspace:
    id: str
    label: str
    tabs: list[Tab] = field(default_factory=list)
    version: int = SCHEMA_VERSION
