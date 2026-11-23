#!/bin/sh
set -eu

TOOLS=${TOOLS:-/tmp/rmcap}
RAW=${RAW:-$TOOLS/raw}
OUT=${OUT:-docs/assets}

mkdir -p "$OUT"

read -r _ _ _ _ _ _ _ drop_x drop_y drop_w drop_h < "$RAW/menubar.geom"

box_w=$((drop_w * 2))
box_h=$((drop_h * 2))
box_x=$((drop_x * 2))
box_y=$((drop_y * 2))
panel_w=560

"$TOOLS/compose" grid 1280 640 "$RAW/grid1280.png"

ffmpeg -hide_banner -loglevel error \
    -i "$RAW/toggle.mov" -i "$RAW/scroll.mov" -i "$RAW/menubar.mov" \
    -loop 1 -framerate 30 -i "$RAW/grid1280.png" \
    -filter_complex "\
[0:v]scale=1280:640,fps=30,setsar=1[a];\
[1:v]scale=1280:640,fps=30,setsar=1[b];\
[2:v]trim=start=0.2:end=5.4,setpts=PTS-STARTPTS,fps=30,crop=${box_w}:${box_h}:${box_x}:${box_y},scale=${panel_w}:-1,setsar=1[fg];\
[3:v]trim=start=0:end=5.2,setpts=PTS-STARTPTS,fps=30[bg];\
[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1[c];\
[a][b][c]concat=n=3:v=1:a=0,fade=t=in:st=0:d=0.25,fade=t=out:st=21.6:d=0.35[v]" \
    -map "[v]" -an -c:v libx264 -preset slow -crf 25 -pix_fmt yuv420p -movflags +faststart \
    -y "$OUT/demo.mp4"

ffmpeg -hide_banner -loglevel error -i "$OUT/demo.mp4" \
    -vf "fps=15,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
    -loop 0 -y "$OUT/demo.gif"

ffmpeg -hide_banner -loglevel error -ss 5.95 -i "$OUT/demo.mp4" -frames:v 1 -y "$OUT/demo-poster.png"

for file in "$OUT/demo.mp4" "$OUT/demo.gif" "$OUT/demo-poster.png"; do
    printf '%s  %s  %s\n' "$file" "$(du -h "$file" | cut -f1)" "$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$file")"
done
