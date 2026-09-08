#!/usr/bin/env bash

BATTERY_INFO=$(pmset -g batt)
PERCENTAGE=$(printf '%s\n' "$BATTERY_INFO" | grep -o '[0-9]\+%' | cut -d% -f1)

if [[ -z "$PERCENTAGE" ]]; then
  exit 0
fi

case ${PERCENTAGE} in
9[0-9] | 100)
  ICON=""
  # ICON_COLOR="0xff40a02b"
  ;;
[6-8][0-9])
  ICON=""
  # ICON_COLOR="0xff179299"
  ;;
[3-5][0-9])
  ICON=""
  # ICON_COLOR="0xfffe640b"
  ;;
[1-2][0-9])
  ICON=""
  # ICON_COLOR="0xffdf8e1d"
  ;;
*)
  ICON=""
  # ICON_COLOR="0xffd20f39"
  ;;
esac

sketchybar --set "$NAME" \
    icon="$ICON" \
    label="${PERCENTAGE}%"
