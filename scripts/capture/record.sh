#!/bin/sh
set -eu

TOOLS=${TOOLS:-/tmp/rmcap}
RAW=${RAW:-$TOOLS/raw}
# unresolved on purpose: run scripts/capture/record.sh with BUILD=/path/to/Debug/reMouse.app
BUILD=${BUILD:?set BUILD to the Debug reMouse.app path}
UNTRUSTED=${UNTRUSTED:-/tmp/remouse-rec/reMouse.app}
DEVICE=${DEVICE:-Capture screen 1}
STEP=${1:-all}

mkdir -p "$RAW"
cd "$(dirname "$0")/../.."

line=$($TOOLS/screens | grep -i "built-in" || $TOOLS/screens | sed -n 2p)
SX=$(printf '%s' "$line" | cut -f3)
SW=$(printf '%s' "$line" | cut -f5)
SH=$(printf '%s' "$line" | cut -f6)
SCALE=2
MAIN_W=$($TOOLS/screens | sed -n 1p | cut -f5)
MAIN_H=$($TOOLS/screens | sed -n 1p | cut -f6)

STAGE_X=$((SX + 156))
STAGE_Y=196
STAGE_W=1200
STAGE_H=600
FACE_X=$((SX + 576))
FACE_Y=270
SIDE_X=$((SX + 180))
PAGE_X=$((SX + 580))
PAGE_Y=270
WHEEL_X=$((PAGE_X + 350))
WHEEL_Y=$((PAGE_Y + 226))
SAVE=$RAW/wallpaper.json

pid_of() { pgrep -f "$BUILD/Contents/MacOS/reMouse" | head -1 || true; }
uid_of() { pgrep -f "$UNTRUSTED/Contents/MacOS/reMouse" | head -1 || true; }

stop_stage() { pkill -x Stage 2>/dev/null || true; }

start_stage() {
    stop_stage
    sleep 0.4
    "$TOOLS/Stage" "$@" >"$RAW/stage.log" 2>&1 &
    sleep 1
}

quit_app() {
    pkill -f "$BUILD/Contents/MacOS/reMouse" 2>/dev/null || true
    sleep 1
}

start_app() {
    quit_app
    if [ "${SUPPRESS:-0}" = "1" ]; then
        ("$BUILD/Contents/MacOS/reMouse" -invertEnabled NO >"$RAW/app.log" 2>&1 &)
    else
        ("$BUILD/Contents/MacOS/reMouse" >"$RAW/app.log" 2>&1 &)
    fi
    waits=0
    while [ -z "$(pid_of)" ] && [ "$waits" -lt 80 ]; do
        sleep 0.25
        waits=$((waits + 1))
    done
    sleep 2.5
}

wait_stage() {
    tries=0
    while [ "$tries" -lt 30 ]; do
        screencapture -x -R "$1,$2,8,8" -t png "$RAW/probe.png"
        luma=$(ffmpeg -v error -i "$RAW/probe.png" -vf "scale=1:1" -f rawvideo -pix_fmt gray - | od -An -tu1 | tr -d ' \n')
        [ "${luma:-255}" -lt 24 ] && return 0
        sleep 0.3
        tries=$((tries + 1))
    done
    echo "stage not ready at $1,$2 (luma=$luma)"
    return 1
}

record() {
    name=$1
    duration=$2
    x=$3
    y=$4
    w=$5
    h=$6
    crop="$((w * SCALE)):$((h * SCALE)):$((x * SCALE)):$((y * SCALE))"
    device=${7:-$DEVICE}
    ffmpeg -hide_banner -loglevel error -f avfoundation -framerate 30 -capture_cursor 0 \
        -i "$device" -t "$duration" -vf "crop=$crop" -an \
        -c:v libx264 -preset veryfast -crf 12 -pix_fmt yuv420p -y "$RAW/$name.mov" &
    echo $! >"$RAW/$name.ffpid"
}

finish_record() {
    name=$1
    wait "$(cat "$RAW/$name.ffpid")"
    rm -f "$RAW/$name.ffpid"
    echo "recorded $RAW/$name.mov $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$RAW/$name.mov")s"
}

window_id() {
    "$TOOLS/winlist" | awk -F'\t' -v owner="$1" -v want="$2" '$6 == owner && $2 == ("layer=" want) { print $1; exit }'
}

icon_box() {
    "$TOOLS/axctl" "$1" findbar "$((MAIN_W - 6))" 300 12
}

drop_geometry() {
    "$TOOLS/axctl" "$1" list | grep '^AXWindow title=""' | head -1 \
        | sed -E 's/.*@([0-9]+),([0-9]+) ([0-9]+)x([0-9]+).*/\1 \2 \3 \4/'
}

ensure_invert() {
    state=$("$TOOLS/axctl" "$1" value "Invert scroll" || true)
    if [ "$state" != "$2" ]; then
        "$TOOLS/axctl" "$1" press "Invert scroll" >/dev/null
        sleep 0.6
    fi
}

step_toggle() {
    start_app
    app=$(pid_of)
    "$TOOLS/axctl" "$app" place "$FACE_X" "$FACE_Y"
    start_stage --backdrop "$STAGE_X,$STAGE_Y,$STAGE_W,$STAGE_H"
    ensure_invert "$app" "On"
    wait_stage "$((STAGE_X + 6))" "$((STAGE_Y + 6))"
    record toggle 8.6 "$((STAGE_X - SX))" "$STAGE_Y" "$STAGE_W" "$STAGE_H"
    sleep 1
    "$TOOLS/axctl" "$app" press "Invert scroll"
    sleep 1.6
    "$TOOLS/axctl" "$app" press "Invert scroll"
    sleep 1.6
    "$TOOLS/axctl" "$app" press "Invert scroll"
    sleep 1.6
    "$TOOLS/axctl" "$app" press "Invert scroll"
    finish_record toggle
}

step_scroll() {
    app=$(pid_of)
    [ -n "$app" ] || { start_app; app=$(pid_of); }
    "$TOOLS/axctl" "$app" place "$SIDE_X" "$PAGE_Y"
    start_stage --backdrop "$STAGE_X,$STAGE_Y,$STAGE_W,$STAGE_H" --page "$PAGE_X,$PAGE_Y,700,452"
    ensure_invert "$app" "On"
    wait_stage "$((STAGE_X + 6))" "$((STAGE_Y + 6))"
    record scroll 8.2 "$((STAGE_X - SX))" "$STAGE_Y" "$STAGE_W" "$STAGE_H"
    sleep 1
    "$TOOLS/wheel" "$WHEEL_X" "$WHEEL_Y" 3 13 105
    sleep 0.6
    "$TOOLS/axctl" "$app" press "Invert scroll"
    sleep 1
    "$TOOLS/wheel" "$WHEEL_X" "$WHEEL_Y" 3 13 105
    sleep 0.6
    "$TOOLS/axctl" "$app" press "Invert scroll"
    finish_record scroll
}

step_menubar() {
    app=$(pid_of)
    [ -n "$app" ] || { start_app; app=$(pid_of); }
    ensure_invert "$app" "On"
    icon=$(icon_box "$app")
    set -- $icon
    icon_x=$1
    icon_y=$2
    icon_w=$3
    icon_h=$4
    "$TOOLS/axctl" "$app" click "$((icon_x + icon_w / 2))" "$((icon_y + icon_h / 2))" >/dev/null
    sleep 1.4
    geom=$(drop_geometry "$app")
    set -- $geom
    drop_x=$1
    drop_y=$2
    drop_w=$3
    drop_h=$4
    left=$((icon_x - 12))
    [ "$drop_x" -lt "$left" ] && left=$((drop_x - 12))
    right=$((icon_x + icon_w + 12))
    [ $((drop_x + drop_w + 12)) -gt "$right" ] && right=$((drop_x + drop_w + 12))
    bottom=$((drop_y + drop_h + 14))
    width=$((right - left))
    start_stage --backdrop "$left,0,$width,$bottom" --level 3
    echo "menubar rect $left,0 ${width}x${bottom} icon=$icon drop=$geom"
    record menubar 7.4 "$left" 0 "$width" "$bottom" "Capture screen 0"
    sleep 1
    "$TOOLS/axctl" "$app" press-at "$((drop_x + drop_w / 2))" "$((drop_y + 66))" >/dev/null
    sleep 1.7
    "$TOOLS/axctl" "$app" press-at "$((drop_x + drop_w / 2))" "$((drop_y + 66))" >/dev/null
    sleep 1.7
    "$TOOLS/axctl" "$app" click "$((icon_x + icon_w / 2))" "$((icon_y + icon_h / 2))" >/dev/null
    finish_record menubar
    echo "$left 0 $width $bottom $((icon_x - 12 - left)) $((icon_w + 24)) 30 $((drop_x - left)) $drop_y $drop_w $drop_h" >"$RAW/menubar.geom"
}

step_stills() {
    app=$(pid_of)
    [ -n "$app" ] || { start_app; app=$(pid_of); }
    stop_stage
    "$TOOLS/axctl" "$app" place "$FACE_X" "$FACE_Y" >/dev/null
    ensure_invert "$app" "On"
    sleep 1
    main_id=$(window_id "$app" 0)
    screencapture -x -o -l "$main_id" -t png "$RAW/main-on.png"
    "$TOOLS/axctl" "$app" press "Invert scroll" >/dev/null
    sleep 1.2
    screencapture -x -o -l "$main_id" -t png "$RAW/main-off.png"
    "$TOOLS/axctl" "$app" press "Invert scroll" >/dev/null
    sleep 0.8
    icon=$(icon_box "$app")
    set -- $icon
    "$TOOLS/axctl" "$app" click "$(($1 + $3 / 2))" "$(($2 + $4 / 2))" >/dev/null
    sleep 1.4
    drop_id=$(window_id "$app" 101)
    screencapture -x -o -l "$drop_id" -t png "$RAW/menu-dropdown.png"
    "$TOOLS/axctl" "$app" click "$(($1 + $3 / 2))" "$(($2 + $4 / 2))" >/dev/null
    for shot in main-on main-off menu-dropdown; do
        echo "$shot $(ffprobe -v error -show_entries stream=width,height -of csv=p=0 "$RAW/$shot.png")"
    done
}

step_permission() {
    quit_app
    stop_stage
    open -a "$UNTRUSTED"
    waits=0
    while [ -z "$(uid_of)" ] && [ "$waits" -lt 60 ]; do
        sleep 0.25
        waits=$((waits + 1))
    done
    sleep 3
    untrusted_id=$(window_id "$(uid_of)" 0)
    screencapture -x -o -l "$untrusted_id" -t png "$RAW/permission.png"
    echo "permission $(ffprobe -v error -show_entries stream=width,height -of csv=p=0 "$RAW/permission.png")"
    pkill -f "$UNTRUSTED/Contents/MacOS/reMouse" 2>/dev/null || true
}

step_dark() {
    ffmpeg -hide_banner -loglevel error -f lavfi -i "color=c=0x0A0A0A:s=256x256" -frames:v 1 -y "$RAW/void.png"
    [ -f "$SAVE" ] || "$TOOLS/wallpaper" save "$SAVE" >/dev/null
    "$TOOLS/wallpaper" solid "$RAW/void.png" 0
}

step_restore() {
    if [ -f "$SAVE" ]; then
        "$TOOLS/wallpaper" restore "$SAVE"
    fi
}

cleanup() {
    stop_stage
    quit_app
    pkill -f "$UNTRUSTED/Contents/MacOS/reMouse" 2>/dev/null || true
}

case "$STEP" in
toggle) step_toggle ;;
scroll) step_scroll ;;
menubar) step_menubar ;;
stills) step_stills ;;
permission) step_permission ;;
dark) step_dark ;;
restore) step_restore ;;
cleanup) cleanup ;;
geometry)
    echo "builtin origin=$SX,$SY width=$SW height=$SH main=${MAIN_W}x${MAIN_H}"
    echo "stage=$STAGE_X,$STAGE_Y ${STAGE_W}x${STAGE_H} face=$FACE_X,$FACE_Y side=$SIDE_X page=$PAGE_X,$PAGE_Y"
    ;;
*)
    step_dark
    step_toggle
    step_scroll
    step_stills
    step_menubar
    step_restore
    step_permission
    cleanup
    ;;
esac
