#!/bin/zsh

# The $SELECTED variable is available for space components and indicates if
# the space invoking this script (with name: $NAME) is currently selected:
# https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item

SPACE_ICONS=(
  "󰎦󰎤"
  "󰎩󰎧"
  "󰎬󰎪"
  "󰎮󰎭"
  "󰎰󰎱"
  "󰎵󰎳"
  "󰎸󰎶"
  "󰎻󰎹"
  "󰎾󰎼"
  "󰽾󰽽"
)

echo "$SID $SELECTED" > /tmp/space.log

# 2. Convert SELECTED ("true"/"false") to character offset (0/1)
if [[ "$SELECTED" = "true" ]]; then
  OFFSET=1
else
  OFFSET=0
fi

# 3. Perform the slice cleanly
ICON="${SPACE_ICONS[$SID]:$OFFSET:1}"

sketchybar --set "$NAME" icon="$ICON"
