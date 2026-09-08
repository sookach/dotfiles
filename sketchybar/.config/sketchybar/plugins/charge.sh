#!/usr/bin/env bash

BATTERY_INFO=$(pmset -g batt)
ICON=''
if printf '%s\n' "$BATTERY_INFO" | grep -q 'AC Power'; then
   ICON='' 
fi

sketchybar --set "$NAME" \
    icon="$ICON" \
