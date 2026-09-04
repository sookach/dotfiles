#!/bin/sh

yabai=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq

current=$("$yabai" -m query --windows --window | "$jq" -r '.id // empty') || exit 1
sibling=$("$yabai" -m query --windows --window sibling 2>/dev/null | "$jq" -r '.id // empty') || sibling=

"$yabai" -m window "$current" --close

if [ -n "$sibling" ]; then
  "$yabai" -m window "$sibling" --focus
fi
