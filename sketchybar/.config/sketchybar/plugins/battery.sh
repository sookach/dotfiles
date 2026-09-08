#!/usr/bin/env bash

BATTERY_INFO=$(pmset -g batt)
PERCENTAGE=$(printf '%s\n' "$BATTERY_INFO" | grep -o '[0-9]\+%' | cut -d% -f1)

CHARGE=0
if printf '%s\n' "$BATTERY_INFO" | grep -q 'AC Power'; then
   CHARGE=1 
fi

if [[ -z "$PERCENTAGE" ]]; then
  exit 0
fi

case ${PERCENTAGE} in
9[0-9] | 100)
  if (( CHARGE == 1 )); then
    ICON='󰂅'
  else
    ICON='󰁹'
  fi
  ;;
[6-8][0-9])
  if (( CHARGE == 1 )); then
    ICON='󰂊'
  else
    ICON='󰂁'
  fi
  ;;
[3-5][0-9])
  if (( CHARGE == 1 )); then
    ICON='󰢝'
  else
    ICON='󰁾'
  fi
  ;;
[1-2][0-9])
  if (( CHARGE == 1 )); then
    ICON='󰂆'
  else
    ICON='󰁻'
  fi
  ;;
*)
  if (( CHARGE == 1 )); then
    ICON='󰢟'
  else
    ICON='󰂎'
  fi
  ;;
esac

sketchybar --set "$NAME" \
    icon="$ICON" \
    label="${PERCENTAGE}%"
