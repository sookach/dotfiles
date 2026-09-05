#!/bin/sh

yabai=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq
hs=/opt/homebrew/bin/hs
vicinae=/opt/homebrew/bin/vicinae
target=${1:-}

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

if [ -z "$target" ]; then
  target=$(
    i=1
    while [ "$i" -le 99 ]; do
      printf '%s\n' "$i"
      i=$((i + 1))
    done | "$vicinae" dmenu --format data --placeholder "Space number" --section-title "Spaces"
  ) || exit 0
fi

case "$target" in
  ''|*[!0-9]*) fail "Space number must be a positive integer." ;;
esac

if [ "$target" -lt 1 ]; then
  fail "Space number must be greater than zero."
fi

space_count() {
  spaces=$("$yabai" -m query --spaces) || return 1
  printf '%s\n' "$spaces" | "$jq" -r 'length'
}

count=$(space_count) || fail "Could not query Spaces with yabai."

case "$count" in
  ''|*[!0-9]*) fail "Could not determine the current Space count." ;;
esac

while [ "$count" -lt "$target" ]; do
  next=$((count + 1))
  close_mission_control=true

  if ! "$hs" -q -n -c "assert(hs.spaces.addSpaceToScreen(hs.screen.mainScreen(), $close_mission_control))" >/dev/null; then
    fail "Could not create Space $next. Make sure Hammerspoon is running."
  fi

  attempts=0
  while [ "$attempts" -lt 20 ]; do
    sleep 0.35
    count=$(space_count) || fail "Could not query Spaces with yabai."
    if [ "$count" -ge "$next" ]; then
      break
    fi
    attempts=$((attempts + 1))
  done

  if [ "$count" -lt "$next" ]; then
    fail "Space creation did not finish in time."
  fi
done

focused=$("$yabai" -m query --spaces | "$jq" -r --arg target "$target" \
  '.[] | select(.index == ($target | tonumber)) | .["has-focus"]') || {
  fail "Could not query the target Space."
}

if [ "$focused" != "true" ]; then
  "$yabai" -m space --focus "$target" || fail "Could not focus Space $target."
fi

printf 'Focused Space %s\n' "$target"
