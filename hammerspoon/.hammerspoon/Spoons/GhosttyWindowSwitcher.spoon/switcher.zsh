#!/bin/zsh

readonly yabai="/opt/homebrew/bin/yabai"
readonly jq="/opt/homebrew/bin/jq"
readonly fzf="/opt/homebrew/bin/fzf"

previous_id="${1:-}"
switcher_id="${2:-}"

selected_id=$(
  "$yabai" -m query --windows |
    "$jq" -r --arg switcher_id "$switcher_id" '
      .[]
      | select(."has-ax-reference" == true)
      | select((.id | tostring) != $switcher_id)
      | [
          .id,
          ((.app // "Unknown application") + " | " + (.title // "") + " | Space " + ((.space // "") | tostring))
        ]
      | @tsv
    ' |
    "$fzf" --height=100% --layout=reverse --border=rounded --prompt='Window > ' --no-multi --exit-0 |
    cut -f1
)

focus_id="$selected_id"
if [[ -z "$focus_id" ]]; then
  focus_id="$previous_id"
fi

if [[ -n "$focus_id" ]]; then
  "$yabai" -m window "$focus_id" --focus
  /usr/bin/nohup /bin/sh -c 'sleep 0.15; /opt/homebrew/bin/yabai -m window "$1" --focus' sh "$focus_id" >/dev/null 2>&1 &
fi

sleep 0.05
if [[ -n "$switcher_id" ]]; then
  "$yabai" -m window "$switcher_id" --close
fi
