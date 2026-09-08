#!/usr/bin/env bash

# Replace these placeholders with the final glyphs.
ICON_WIFI_4="󰤨"
ICON_WIFI_3="󰤥"
ICON_WIFI_2="󰤢"
ICON_WIFI_1="󰤟"
ICON_WIFI_OFF="󰤮"

ICON_VPN_CONNECTED=""
ICON_VPN_CONNECTING=""
ICON_VPN_OFF=""

BINARY_DIR="${BINARY_DIR:-$HOME/.config/sketchybar/bin}"
WIFI_STATUS="$BINARY_DIR/wifi-status"
WINDSCRIBE_CLI="${WINDSCRIBE_CLI:-/usr/local/bin/windscribe-cli}"

wifi_status=$($WIFI_STATUS 2>/dev/null)
IFS='|' read -r wifi_connection signal_dbm <<< "$wifi_status"

if [[ "$wifi_connection" != "connected" ]]; then
    sketchybar --set "$NAME" \
        icon="$ICON_WIFI_OFF" \
        label="$ICON_VPN_OFF"
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
    4) wifi_icon="$ICON_WIFI_4" ;;
    3) wifi_icon="$ICON_WIFI_3" ;;
    2) wifi_icon="$ICON_WIFI_2" ;;
    *) wifi_icon="$ICON_WIFI_1" ;;
esac

vpn_state="off"
if [[ -x "$WINDSCRIBE_CLI" ]]; then
    connect_state=$($WINDSCRIBE_CLI status 2>/dev/null \
        | /usr/bin/awk -F 'Connect state: ' '/Connect state:/{state=$2} END{print state}')

    case "$connect_state" in
        Connected:*)
            vpn_state="connected"
            ;;
        Connecting*|Authenticating*|Disconnecting*)
            vpn_state="connecting"
            ;;
    esac
fi

case "$vpn_state" in
    connected)
        vpn_icon="$ICON_VPN_CONNECTED"
        ;;
    connecting)
        vpn_icon="$ICON_VPN_CONNECTING"
        ;;
    *)
        vpn_icon="$ICON_VPN_OFF"
        ;;
esac

sketchybar --set "$NAME" \
    icon="$wifi_icon" \
    label="$vpn_icon"
