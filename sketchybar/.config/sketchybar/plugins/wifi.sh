#!/usr/bin/env bash

ICON_WIFI_4="󰤨"
ICON_WIFI_3="󰤥"
ICON_WIFI_2="󰤢"
ICON_WIFI_1="󰤟"
ICON_WIFI_OFF="󰤮"

wifi_device=$(/usr/sbin/networksetup -listallhardwareports \
  | /usr/bin/awk '/Hardware Port: Wi-Fi/{getline; print $2}')

if [[ -z "$wifi_device" ]]; then
    sketchybar --set "$NAME" \
        icon="$ICON_WIFI_OFF" \
        icon.color=0xffd20f39
    exit 0
fi

network=$(/usr/sbin/ipconfig getsummary "$wifi_device" 2>/dev/null \
  | /usr/bin/awk -F ' : ' '$1 ~ /^[[:space:]]*SSID$/ {print $2; exit}')

if [[ -z "$network" ]]; then
    sketchybar --set "$NAME" \
        icon="$ICON_WIFI_OFF" \
        icon.color=0xffd20f39
    exit 0
fi

signal_dbm=$(/usr/sbin/system_profiler SPAirPortDataType -json 2>/dev/null \
  | /usr/bin/jq -r '.. | objects | .spairport_signal_noise? // empty' \
  | /usr/bin/awk 'NR == 1 { print $1 }')

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
        icon="$ICON_WIFI_4"
        icon_color=0xff179299
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
