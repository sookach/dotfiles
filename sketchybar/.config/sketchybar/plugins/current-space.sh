#!/usr/bin/env bash

space=`jq '.["display-1"]' <<< $INFO`

if [[ "$space" =~ ^[0-9]+$ ]]; then
    sketchybar --set "$NAME" label="$space"
fi
