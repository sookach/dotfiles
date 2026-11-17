"""Helpers shared by the kitten entry points. See DESIGN.md."""

from __future__ import annotations

import functools
from typing import Callable


def quiet(main: Callable[[list[str]], str]) -> Callable[[list[str]], str]:
    """Wrap a kitten's main so ctrl+c exits cleanly instead of printing a traceback."""

    @functools.wraps(main)
    def wrapper(args: list[str]) -> str:
        try:
            return main(args)
        except KeyboardInterrupt:
            return ""

    return wrapper
