#!/bin/sh

yabai=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq
hs=/opt/homebrew/bin/hs
vicinae=/opt/homebrew/bin/vicinae
close_space=$HOME/.config/yabai/close-space.sh
threshold=${1:-}

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

if [ -z "$threshold" ]; then
  threshold=$(
    i=1
    while [ "$i" -le 99 ]; do
      printf '%s\n' "$i"
      i=$((i + 1))
    done | "$vicinae" dmenu \
      --format data \
      --placeholder "Delete Spaces >= number" \
      --section-title "Spaces"
  ) || exit 0
fi

case "$threshold" in
  ''|*[!0-9]*) fail "Space threshold must be a positive integer." ;;
esac

if [ "$threshold" -lt 1 ]; then
  fail "Space threshold must be greater than zero."
fi

spaces=$("$yabai" -m query --spaces) || fail "Could not query Spaces with yabai."

target_spaces=$(printf '%s\n' "$spaces" | "$jq" -r \
  --arg threshold "$threshold" '
    [.[] | select(.index >= ($threshold | tonumber))]
    | sort_by(.index)
    | reverse
    | .[]
    | [.index, .id, .display]
    | @tsv
  ')

if [ -z "$target_spaces" ]; then
  printf 'No Spaces at or after %s\n' "$threshold"
  exit 0
fi

survivor_count=$(printf '%s\n' "$spaces" | "$jq" -r \
  --arg threshold "$threshold" '[.[] | select(.index < ($threshold | tonumber))] | length') || {
  fail "Could not determine the surviving Spaces."
}

[ "$survivor_count" -gt 0 ] || fail "The threshold would remove every Space."

target_ids=$(printf '%s\n' "$target_spaces" | "$jq" -Rrs '
  split("\n")
  | map(select(length > 0) | split("\t")[1] | tonumber)
  | join(",")
') || fail "Could not determine target Space IDs."

if ! "$hs" -q -n -c \
  "for _, id in ipairs({$target_ids}) do assert(hs.spaces.spaceType(id) == 'user', 'target Space is not removable') end" \
  </dev/null >/dev/null; then
  fail "At least one target Space cannot be removed."
fi

missing_ax=$(
  "$yabai" -m query --windows |
    "$jq" -r --arg threshold "$threshold" '
      [.[]
       | select(.space >= ($threshold | tonumber))
       | select(."has-ax-reference" != true)
       | .id]
      | join(",")
    '
) || fail "Could not inspect target windows."

[ -z "$missing_ax" ] || fail "Yabai cannot control target windows: $missing_ax"

if ! printf '%s\n' "$target_spaces" | while IFS="$(printf '\t')" read -r index _ display; do
  [ -n "$index" ] || continue
  "$close_space" "$index" || exit 1
done
then
  fail "Could not delete all target Spaces."
fi

printf 'Deleted Spaces at or after %s\n' "$threshold"
