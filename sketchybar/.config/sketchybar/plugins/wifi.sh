#!/usr/bin/env bash

# Replace these placeholder values with the Wi-Fi glyphs you want to use.
ICON_WIFI_4='󰤨'
ICON_WIFI_3='󰤥'
ICON_WIFI_2='󰤢'
ICON_WIFI_1='󰤟'
ICON_WIFI_OFF='󰤮'

BINARY_DIR="${BINARY_DIR:-$HOME/.config/sketchybar/bin}"
WIFI_STATUS="$BINARY_DIR/wifi-status"

status=$($WIFI_STATUS 2>/dev/null)
IFS='|' read -r connection signal_dbm <<< "$status"

if [[ "$connection" != "connected" ]]; then
    sketchybar --set "$NAME" \
        icon="$ICON_WIFI_OFF" \
        icon.color=0xffd20f39
    exit 0
fi

if [[ "$signal_dbm" =~ ^-[0-9]+$ ]]; then
    if (( signal_dbm >= -55 )); then
        signal_level=4
    elif (( signal_dbm >= -67 )); then
        signal_level=3
    elif (( signal_dbm >= -75 )); then
        signal_level=2
    else
        signal_level=1
    fi
else
    signal_level=1
fi

case "$signal_level" in
    4)
        icon="$ICON_WIFI_4"
        icon_color=0xff40a02b
        ;;
    3)
        icon="$ICON_WIFI_3"
        icon_color=0xffffffff
        ;;
    2)
        icon="$ICON_WIFI_2"
        icon_color=0xffdf8e1d
        ;;
    *)
        icon="$ICON_WIFI_1"
        icon_color=0xffd20f39
        ;;
esac

sketchybar --set "$NAME" \
    icon="$icon" \
    icon.color="$icon_color"
