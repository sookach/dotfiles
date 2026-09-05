#!/bin/sh

yabai=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq
hs=/opt/homebrew/bin/hs

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

spaces=$("$yabai" -m query --spaces) || fail "Could not query Spaces with yabai."

current_id=$(printf '%s\n' "$spaces" | "$jq" -r '.[] | select(."has-focus" == true) | .id')
current_index=$(printf '%s\n' "$spaces" | "$jq" -r '.[] | select(."has-focus" == true) | .index')
current_display=$(printf '%s\n' "$spaces" | "$jq" -r '.[] | select(."has-focus" == true) | .display')

[ -n "$current_id" ] || fail "Could not identify the focused Space."
[ -n "$current_index" ] || fail "Could not identify the focused Space index."
[ -n "$current_display" ] || fail "Could not identify the focused display."

space_type=$("$hs" -q -n -c 'return hs.spaces.spaceType(hs.spaces.focusedSpace())' 2>/dev/null) || {
  fail "Could not determine the focused Space type."
}

[ "$space_type" = "user" ] || fail "The current Space cannot be removed."

destination=$(
  printf '%s\n' "$spaces" | "$jq" -r \
    --argjson current_id "$current_id" \
    --argjson display "$current_display" '
      map(select(.display == $display)) as $spaces
      | ([$spaces | to_entries[] | select(.value.id == $current_id)][0].key // null) as $position
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

close_windows() {
  attempts=0
  while [ "$attempts" -lt 100 ]; do
    window_id=$(
      "$yabai" -m query --windows --space "$current_index" |
        "$jq" -r '.[0].id // empty'
    ) || return 1

    [ -n "$window_id" ] || return 0

    "$yabai" -m window "$window_id" --close || return 1
    sleep 0.1
    attempts=$((attempts + 1))
  done

  return 1
}

close_windows || fail "Could not close all windows in the current Space."

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

"$hs" -q -n -c "assert(hs.spaces.removeSpace($current_id))" >/dev/null || {
  fail "Could not remove the current Space."
}

attempts=0
while [ "$attempts" -lt 20 ]; do
  sleep 0.1
  remaining=$(
    "$yabai" -m query --spaces |
      "$jq" -r --argjson current_id "$current_id" 'any(.[]; .id == $current_id)'
  ) || fail "Could not verify Space removal."

  [ "$remaining" = "false" ] && break
  attempts=$((attempts + 1))
done

[ "$remaining" = "false" ] || fail "Space removal did not finish in time."
printf 'Closed Space %s\n' "$current_index"
