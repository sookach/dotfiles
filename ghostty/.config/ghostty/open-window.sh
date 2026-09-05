#!/bin/sh

osascript_new_window() {
  /usr/bin/osascript <<'APPLESCRIPT'
tell application "Ghostty"
  new window
end tell
APPLESCRIPT
}

reload_config() {
  /usr/bin/osascript <<'APPLESCRIPT'
tell application "Ghostty"
  perform action "reload_config" on terminal 1 of front window
end tell
APPLESCRIPT
}

if /usr/bin/pgrep -x Ghostty >/dev/null 2>&1; then
  osascript_new_window
  exit $?
fi

/usr/bin/open -a "Ghostty" || exit 1

attempts=0
while [ "$attempts" -lt 30 ]; do
  if reload_config >/dev/null 2>&1; then
    exit 0
  fi
  sleep 0.1
  attempts=$((attempts + 1))
done

exit 1
