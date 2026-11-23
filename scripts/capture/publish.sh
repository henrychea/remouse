#!/bin/sh
set -eu

TOOLS=${TOOLS:-/tmp/rmcap}
RAW=${RAW:-$TOOLS/raw}
SHOTS=docs/assets/shots
SNAPS=design/snapshots

mkdir -p "$SHOTS" "$SNAPS"

for name in main-on:main-inverted main-off:main-standard permission:permission-content; do
    source_name=${name%%:*}
    target_name=${name##*:}
    "$TOOLS/compose" content "$RAW/$source_name.png" "$RAW/$target_name.png" 64
    if [ "$target_name" = "permission-content" ]; then
        cp "$RAW/$target_name.png" "$SHOTS/permission.png"
        cp "$RAW/$target_name.png" "$SNAPS/permission.png"
    else
        cp "$RAW/$target_name.png" "$SHOTS/$target_name.png"
        cp "$RAW/$target_name.png" "$SNAPS/$target_name.png"
    fi
done

cp "$RAW/menu-dropdown.png" "$SHOTS/menu-bar.png"
cp "$RAW/menu-dropdown.png" "$SNAPS/menu-bar.png"

for file in "$SHOTS"/*.png; do
    printf '%s  %s\n' "$file" "$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$file")"
done
