#!/bin/sh

STATE_FILE="${TMPDIR:-/tmp}/sketchybar-apple-menu-open"

if [ -e "$STATE_FILE" ]; then
    /usr/bin/osascript -e '
        tell application "System Events"
            key code 53
        end tell
    '
    rm -f "$STATE_FILE"
else
    /usr/bin/osascript -e '
      tell application "System Events"
          tell process "Finder"
              click menu bar item 1 of menu bar 1
          end tell
      end tell
    '
    touch "$STATE_FILE"
fi
