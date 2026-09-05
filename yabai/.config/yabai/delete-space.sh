#!/bin/sh

yabai=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq
close_space=$HOME/.config/yabai/close-space.sh

target=$(
  "$yabai" -m query --spaces |
    "$jq" -r '.[].index' |
    /opt/homebrew/bin/vicinae dmenu \
      --format data \
      --placeholder "Space to delete" \
      --section-title "Spaces"
) || exit 0

[ -n "$target" ] || exit 0
exec "$close_space" "$target"
