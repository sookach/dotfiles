#!/usr/bin/env python3

import json
import copy

config: dict = {
    "global": {"show_in_menu_bar": False},
    "profiles": [
        {
            "complex_modifications": {"rules": [{"manipulators": []}]},
            "devices": [
                {
                    "identifiers": {"is_keyboard": True},
                    "simple_modifications": [
                        {
                            "from": {"key_code": "caps_lock"},
                            "to": [{"key_code": "left_control"}],
                        },
                        {
                            "from": {"key_code": "right_shift"},
                            "to": [{"key_code": "tab"}],
                        },
                    ],
                }
            ],
            "name": "Default profile",
            "selected": True,
            "virtual_hid_keyboard": {"keyboard_type_v2": "ansi"},
        }
    ],
}


def hammerspoon_vim_mode(mode):
    return {
        "shell_command": (f"/opt/homebrew/bin/hs -c '_dotfilesSetVimMode(\"{mode}\")'")
    }


def create_manipulator(manipulator):
    manipulator["type"] = "basic"
    config["profiles"][0]["complex_modifications"]["rules"][0]["manipulators"].append(
        manipulator
    )


def create_manipulators(*manipulators):
    for manipulator in manipulators:
        create_manipulator(manipulator)


NEW_SAFARI_WINDOW = """
osascript -e '
  tell application "Safari"
    make new document at end of documents
    activate
  end tell'
'
"""

NEW_FINDER_WINDOW = """
osascript -e '
  tell application "Finder"
    make new Finder window to (get home)
    activate
  end tell
'
"""

PROGRAMS = [
    ("s", NEW_SAFARI_WINDOW),
    ("f", NEW_FINDER_WINDOW),
    ("g", "$HOME/.config/ghostty/open-window.sh"),
]

for c, cmd in PROGRAMS:
    create_manipulator(
        {
            "from": {"key_code": c, "modifiers": {"mandatory": ["option"]}},
            "to": [{"shell_command": cmd}],
        }
    )

create_manipulator(
    {
        "from": {"key_code": "w", "modifiers": {"mandatory": ["control", "command"]}},
        "to": [
            {"shell_command": "$HOME/.config/yabai/close-window-and-focus-sibling.sh"}
        ],
    }
)

for x, y in [("h", "west"), ("j", "south"), ("k", "north"), ("l", "east")]:
    create_manipulator(
        {
            "from": {"key_code": x, "modifiers": {"mandatory": ["control", "command"]}},
            "to": [{"shell_command": f"/opt/homebrew/bin/yabai -m window --focus {y}"}],
        }
    )


for x, y in [("y", "west"), ("u", "south"), ("i", "north"), ("o", "east")]:
    create_manipulator(
        {
            "from": {"key_code": x, "modifiers": {"mandatory": ["control", "command"]}},
            "to": [{"shell_command": f"/opt/homebrew/bin/yabai -m window --warp {y}"}],
        }
    )

for x, y in [
    ("h", "left:-50:0"),
    ("j", "bottom:0:50"),
    ("k", "top:0:-50"),
    ("l", "right:50:0"),
    ("y", "left:50:0"),
    ("u", "bottom:0:-50"),
    ("i", "top:0:50"),
    ("o", "right:-50:0"),
]:
    create_manipulator(
        {
            "from": {
                "key_code": x,
                "modifiers": {"mandatory": ["control", "command", "shift"]},
            },
            "to": [
                {"shell_command": f"/opt/homebrew/bin/yabai -m window --resize {y}"}
            ],
        }
    )

for i in range(1, 10):
    create_manipulators(
        {
            "from": {"key_code": str(i), "modifiers": {"mandatory": ["control"]}},
            "to": [{"shell_command": f"/opt/homebrew/bin/yabai -m space --focus {i}"}],
        },
        {
            "from": {
                "key_code": str(i),
                "modifiers": {"mandatory": ["control", "command"]},
            },
            "to": [{"shell_command": f"/opt/homebrew/bin/yabai -m window --space {i}"}],
        },
    )

for x, y in [("semicolon", "prev"), ("quote", "next"), ("p", "recent")]:
    create_manipulators(
        {
            "from": {"key_code": x, "modifiers": {"mandatory": ["control", "command"]}},
            "to": [{"shell_command": f"/opt/homebrew/bin/yabai -m space --focus {y}"}],
        },
        {
            "from": {
                "key_code": x,
                "modifiers": {"mandatory": ["control", "command", "shift"]},
            },
            "to": [{"shell_command": f"/opt/homebrew/bin/yabai -m window --space {y}"}],
        },
    )

for x, y in [("m", "zoom-fullscreen"), ("comma", "float"), ("period", "split")]:
    create_manipulator(
        {
            "from": {"key_code": x, "modifiers": {"mandatory": ["control", "command"]}},
            "to": [
                {"shell_command": f"/opt/homebrew/bin/yabai -m window --toggle {y}"}
            ],
        }
    )

print(json.dumps(config))

