#!/bin/sh

yabai=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq
hs=/opt/homebrew/bin/hs
target_index=${1:-}

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

spaces=$("$yabai" -m query --spaces) || fail "Could not query Spaces with yabai."

if [ -z "$target_index" ]; then
  target_id=$(printf '%s\n' "$spaces" | "$jq" -r '.[] | select(."has-focus" == true) | .id')
  target_index=$(printf '%s\n' "$spaces" | "$jq" -r '.[] | select(."has-focus" == true) | .index')
  target_display=$(printf '%s\n' "$spaces" | "$jq" -r '.[] | select(."has-focus" == true) | .display')
else
  case "$target_index" in
    ''|*[!0-9]*) fail "Space number must be a positive integer." ;;
  esac

  if [ "$target_index" -lt 1 ]; then
    fail "Space number must be greater than zero."
  fi

  target_id=$(printf '%s\n' "$spaces" | "$jq" -r --arg target "$target_index" \
    '.[] | select(.index == ($target | tonumber)) | .id')
  target_display=$(printf '%s\n' "$spaces" | "$jq" -r --arg target "$target_index" \
    '.[] | select(.index == ($target | tonumber)) | .display')
fi

[ -n "$target_id" ] || fail "Could not identify the target Space."
[ -n "$target_index" ] || fail "Could not identify the target Space index."
[ -n "$target_display" ] || fail "Could not identify the target display."

space_type=$("$hs" -q -n -c "return hs.spaces.spaceType($target_id)" 2>/dev/null) || {
  fail "Could not determine the target Space type."
}

[ "$space_type" = "user" ] || fail "The target Space cannot be removed."

original_focused_id=$(
  "$yabai" -m query --spaces |
    "$jq" -r '.[] | select(."has-focus" == true) | .id'
) || fail "Could not identify the focused Space."

target_is_focused=false
if [ "$original_focused_id" = "$target_id" ]; then
  target_is_focused=true
fi

target_windows=$("$yabai" -m query --windows --space "$target_index") || {
  fail "Could not query windows in the target Space."
}

missing_ax=$(printf '%s\n' "$target_windows" | "$jq" -r \
  '[.[] | select(."has-ax-reference" != true) | .id] | join(",")') || {
  fail "Could not inspect windows in the target Space."
}

[ -z "$missing_ax" ] || fail "Yabai cannot control target windows: $missing_ax"

if [ "$target_is_focused" = true ]; then
  destination=$(
    printf '%s\n' "$spaces" | "$jq" -r \
      --argjson target_id "$target_id" \
      --argjson display "$target_display" '
        map(select(.display == $display)) as $spaces
        | ([$spaces | to_entries[] | select(.value.id == $target_id)][0].key // null) as $position
        | if $position == null then
            empty
          elif $position > 0 then
            $spaces[$position - 1]
          elif ($position + 1) < ($spaces | length) then
            $spaces[$position + 1]
          else
            empty
          end
        | [.id, .index]
        | @tsv
      '
  )

  [ -n "$destination" ] || fail "Cannot remove the only Space."

  destination_id=$(printf '%s\n' "$destination" | "$jq" -Rr 'split("\t")[0]')
  destination_index=$(printf '%s\n' "$destination" | "$jq" -Rr 'split("\t")[1]')
fi

close_windows() {
  attempts=0
  while [ "$attempts" -lt 100 ]; do
    window_id=$(
      "$yabai" -m query --windows --space "$target_index" |
        "$jq" -r '.[0].id // empty'
    ) || return 1

    [ -n "$window_id" ] || return 0

    "$yabai" -m window "$window_id" --close || return 1
    sleep 0.1
    attempts=$((attempts + 1))
  done

  return 1
}

close_windows || fail "Could not close all windows in the target Space."

if [ "$target_is_focused" = true ]; then
  "$yabai" -m space --focus "$destination_index" || fail "Could not focus the neighboring Space."

  attempts=0
  while [ "$attempts" -lt 20 ]; do
    focused_id=$(
      "$yabai" -m query --spaces |
        "$jq" -r '.[] | select(."has-focus" == true) | .id'
    ) || fail "Could not verify the neighboring Space."

    [ "$focused_id" = "$destination_id" ] && break
    sleep 0.01
    attempts=$((attempts + 1))
  done

  [ "$focused_id" = "$destination_id" ] || fail "Could not switch to the neighboring Space."
fi

"$hs" -q -n -c "assert(hs.spaces.removeSpace($target_id))" >/dev/null || {
  fail "Could not remove the target Space."
}

attempts=0
while [ "$attempts" -lt 20 ]; do
  sleep 0.1
  remaining=$(
    "$yabai" -m query --spaces |
      "$jq" -r --argjson target_id "$target_id" 'any(.[]; .id == $target_id)'
  ) || fail "Could not verify Space removal."

  [ "$remaining" = "false" ] && break
  attempts=$((attempts + 1))
done

[ "$remaining" = "false" ] || fail "Space removal did not finish in time."

if [ "$target_is_focused" = false ]; then
  focused_id=$(
    "$yabai" -m query --spaces |
      "$jq" -r '.[] | select(."has-focus" == true) | .id'
  ) || fail "Could not verify the original focused Space."

  [ "$focused_id" = "$original_focused_id" ] || fail "The original focused Space changed unexpectedly."
fi

printf 'Closed Space %s\n' "$target_index"
