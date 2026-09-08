#!/usr/bin/env bash

space=$(
  /opt/homebrew/bin/yabai -m query --spaces --space 2>/dev/null \
    | /usr/bin/jq -r '.index'
)

if [[ "$space" =~ ^[0-9]+$ ]]; then
    sketchybar --set "$NAME" label="$space"
fi
