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
    make new document
    activate
  endtell
'
"""

NEW_FINDER_WINDOW = """
osascript -e '
  tell application "Finder"
    make new Finder window to (get home)
    activate
  endtell
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

create_manipulators(
    {
        "from": {"key_code": "s", "modifiers": {"mandatory": ["control", "command"]}},
        "to": [{"shell_command": "$HOME/.config/yabai/focus-or-create-space.sh"}],
    },
    {
        "from": {"key_code": "d", "modifiers": {"mandatory": ["control", "command"]}},
        "to": [{"shell_command": "$HOME/.config/yabai/close-space.sh"}],
    },
    {
        "from": {
            "key_code": "d",
            "modifiers": {"mandatory": ["control", "command", "shift"]},
        },
        "to": [{"shell_command": "$HOME/.config/yabai/delete-space.sh"}],
    },
    {
        "from": {"key_code": "d", "modifiers": {"mandatory": ["option", "shift"]}},
        "to": [{"shell_command": "$HOME/.config/yabai/delete-spaces-from.sh"}],
    },
    {
        "from": {"key_code": "w", "modifiers": {"mandatory": ["control", "command"]}},
        "to": [
            {"shell_command": "$HOME/.config/yabai/close-window-and-focus-sibling.sh"}
        ],
    },
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
                {"shell_command": f"/opt/homebrew/bin/yabai -m window --resize ${y}"}
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

create_manipulators(
    {
        "from": {"key_code": "c", "modifiers": {"mandatory": ["control", "command"]}},
        "to": [
            {"set_variable": {"name": "vim_mode", "value": 0}},
            {"set_variable": {"name": "vim_count", "value": 0}},
        ],
    },
    {
        "from": {"key_code": "x", "modifiers": {"mandatory": ["control", "command"]}},
        "to": [
            {"set_variable": {"name": "vim_mode", "value": 1}},
            {"set_variable": {"name": "vim_count", "value": 0}},
        ],
    },
    {
        "conditions": [{"type": "variable_if", "name": "vim_mode", "value": 0}],
        "from": {"key_code": "i"},
        "to": [{"set_variable": {"name": "vim_mode", "value": 1}}],
    },
    {
        "conditions": [{"type": "variable_if", "name": "vim_mode", "value": 0}],
        "from": {"key_code": "v"},
        "to": [{"set_variable": {"name": "vim_mode", "value": 2}}],
    },
)

for i in range(0, 10):
    create_manipulator(
        {
            "conditions": [
                {"type": "variable_if", "name": "vim_mode", "value": 0},
                {"type": "variable_if", "name": "vim_mode", "value": 2},
            ],
            "from": {"key_code": str(i)},
            "to": [
                {
                    "set_variable": {
                        "name": "vim_count",
                        "expression": f"vim_count * 10 + i",
                    }
                }
            ],
        }
    )


def repeat_action(x, n):
    y = []
    for i in range(n):
        y.append(x)
    return y


for x, y in [
    ("h", "left_arrow"),
    ("j", "down_arrow"),
    ("k", "down_arrow"),
    ("l", "right_arrow"),
]:
    for i in range(0, 100):
        create_manipulators(
            {
                "conditions": [
                    {"type": "variable_if", "name": "vim_mode", "value": 0},
                    {"type": "variable_if", "name": "vim_count", "value": i},
                ],
                "from": {"key_code": x},
                "to": [
                    {
                        "set_variable": {
                            "name": "vim_count",
                            "value": 0,
                        }
                    },
                ]
                + repeat_action({"key_code": y}, i),
            },
            {
                "conditions": [
                    {"type": "variable_if", "name": "vim_mode", "value": 2},
                    {"type": "variable_if", "name": "vim_count", "value": i},
                ],
                "from": {"key_code": x},
                "to": [
                    {
                        "set_variable": {
                            "name": "vim_count",
                            "value": 0,
                        }
                    },
                ]
                + repeat_action({"key_code": y, "modifiers": ["shift"]}, i),
            },
        )

for x, y in [("w", "right_arrow"), ("e", "right_arrow"), ("b", "left_arrow")]:
    create_manipulators(
        {
            "conditions": [{"type": "variable_if", "name": "vim_mode", "value": 0}],
            "from": {"key_code": x},
            "to": [{"key_code": y, "modifiers": ["option"]}],
        },
        {
            "conditions": [{"type": "variable_if", "name": "vim_mode", "value": 0}],
            "from": {"key_code": x},
            "to": [{"key_code": y, "modifiers": ["option"]}],
        },
        {
            "conditions": [{"type": "variable_if", "name": "vim_mode", "value": 0}],
            "from": {"key_code": "b"},
            "to": [{"key_code": y, "modifiers": ["option"]}],
        },
        {
            "conditions": [{"type": "variable_if", "name": "vim_mode", "value": 0}],
            "from": {"key_code": x},
            "to": [{"key_code": y, "modifiers": ["option", "shift"]}],
        },
        {
            "conditions": [{"type": "variable_if", "name": "vim_mode", "value": 0}],
            "from": {"key_code": x},
            "to": [{"key_code": y, "modifiers": ["option", "shift"]}],
        },
        {
            "conditions": [{"type": "variable_if", "name": "vim_mode", "value": 0}],
            "from": {"key_code": "b"},
            "to": [{"key_code": y, "modifiers": ["option", "shift"]}],
        },
    )


print(json.dumps(config))

