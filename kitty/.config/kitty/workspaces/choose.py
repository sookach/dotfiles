"""Pick one item from a list: fzf (fuzzy search, arrow keys) when installed, else a numbered prompt.

Pure helpers (fzf_args, parse_fzf_output) are separate from the process call so they can be
tested without fzf. See DESIGN.md.
"""

from __future__ import annotations

import os
import shutil
import subprocess

FZF_FALLBACK = "/opt/homebrew/bin/fzf"


def fzf_bin() -> str | None:
    found = shutil.which("fzf")
    if found:
        return found
    return FZF_FALLBACK if os.path.exists(FZF_FALLBACK) else None


def fzf_args(prompt: str, expect: tuple[str, ...] = ()) -> list[str]:
    args = ["--prompt", prompt, "--layout", "reverse", "--height", "100%",
            "--delimiter", "\t", "--with-nth", "2.."]
    if expect:
        args += ["--expect", ",".join(expect)]
    return args


def parse_fzf_output(out: str, expect: tuple[str, ...] = ()) -> tuple[str | None, int | None]:
    """(key pressed or None, selected index or None). Items are fed as '<index>\\t<label>'."""
    lines = out.split("\n")
    key: str | None = None
    if expect:
        key = lines[0] or None
        lines = lines[1:]
    selected = lines[0] if lines and lines[0] else None
    if selected is None:
        return key, None
    return key, int(selected.split("\t", 1)[0])


def choose(
    items: list[str], prompt: str, expect: tuple[str, ...] = ()
) -> tuple[str | None, int] | None:
    """Ask the user to pick one of `items`. Returns (key, index), or None if cancelled.

    `expect` lists keys that also end the pick (e.g. "ctrl-x"); the key is returned.
    """
    if not items:
        return None
    fz = fzf_bin()
    if fz:
        feed = "\n".join(f"{i}\t{label}" for i, label in enumerate(items))
        res = subprocess.run([fz, *fzf_args(prompt, expect)], input=feed, capture_output=True, text=True)
        if res.returncode != 0:  # 1: no match, 130: cancelled
            return None
        key, index = parse_fzf_output(res.stdout, expect)
        return None if index is None else (key, index)

    for i, label in enumerate(items, start=1):
        print(f"  {i}. {label}")
    raw = input(f"\n{prompt}number (blank to cancel): ").strip()
    if not raw.isdigit() or not 1 <= int(raw) <= len(items):
        return None
    return (None, int(raw) - 1)
