#!/usr/bin/env bash

app_name="${INFO:-}"

if [[ -z "$app_name" ]]; then
    exit 0
fi

sketchybar --set "$NAME" \
    icon=" " \
    icon.drawing=on \
    icon.background.drawing=on \
    icon.background.image="app.$app_name" \
    icon.background.image.scale=0.5 \
    label.drawing=off
