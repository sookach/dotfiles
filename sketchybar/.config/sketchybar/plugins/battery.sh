#!/usr/bin/env bash

BATTERY_INFO=$(pmset -g batt)
PERCENTAGE=$(printf '%s\n' "$BATTERY_INFO" | grep -o '[0-9]\+%' | cut -d% -f1)

FONT="NotoSansM Nerd Font Mono:Bold:12.0"
CHARGE=0
if printf '%s\n' "$BATTERY_INFO" | grep -q 'AC Power'; then
  CHARGE=1 
  FONT="NotoSansM Nerd Font Mono:Bold:18.0"
fi

if [[ -z "$PERCENTAGE" ]]; then
  exit 0
fi

case ${PERCENTAGE} in
100)
  if (( CHARGE == 1 )); then
    ICON='󰂅'
  else
    ICON='󰁹'
  fi
  ;;
9[0-9])
  if (( CHARGE == 1 )); then
    ICON='󰂋'
  else
    ICON='󰂂'
  fi
  ;;
8[0-9])
  if (( CHARGE == 1 )); then
    ICON='󰂊'
  else
    ICON='󰂁'
  fi
  ;;
7[0-9])
  if (( CHARGE == 1 )); then
    ICON='󰢞'
  else
    ICON='󰂀'
  fi
  ;;
6[0-9])
  if (( CHARGE == 1 )); then
    ICON='󰂉'
  else
    ICON='󰁿'
  fi
  ;;
5[0-9])
  if (( CHARGE == 1 )); then
    ICON='󰢝'
  else
    ICON='󰁾'
  fi
  ;;
4[0-9])
  if (( CHARGE == 1 )); then
    ICON='󰂈'
  else
    ICON='󰁽'
  fi
  ;;
3[0-9])
  if (( CHARGE == 1 )); then
    ICON='󰂇'
  else
    ICON='󰁼'
  fi
  ;;
2[0-9])
  if (( CHARGE == 1 )); then
    ICON='󰂆'
  else
    ICON='󰁻'
  fi
  ;;
1[0-9])
  if (( CHARGE == 1 )); then
    ICON='󰂆'
  else
    ICON='󰢜'
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
    icon.font="$FONT" \
    label="${PERCENTAGE}%"
