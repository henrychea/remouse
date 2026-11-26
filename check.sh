#!/bin/sh
set -eu
cd "$(dirname "$0")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/main.swift" <<'EOF'
let sample = ScrollDeltas(axis1: -3, axis2: 2, point1: -12, point2: 8, fixed1: -65536, fixed2: 65536)
let flipped = ScrollDeltas(axis1: 3, axis2: -2, point1: 12, point2: -8, fixed1: 65536, fixed2: -65536)
let zero = ScrollDeltas(axis1: 0, axis2: 0, point1: 0, point2: 0, fixed1: 0, fixed2: 0)
let extreme = ScrollDeltas(axis1: .min, axis2: .max, point1: 0, point2: 0, fixed1: 0, fixed2: 0)
let fractional = ScrollDeltas(axis1: -3, axis2: 2, point1: -12, point2: 8, fixed1: -65536.5, fixed2: 131072.25)

precondition(invertedDeltas(sample, isContinuous: false, enabled: true) == flipped, "wheel event inverts")
precondition(invertedDeltas(sample, isContinuous: true, enabled: true) == sample, "trackpad passes through")
precondition(invertedDeltas(sample, isContinuous: false, enabled: false) == sample, "disabled passes through")
precondition(invertedDeltas(zero, isContinuous: false, enabled: true) == zero, "zero stays zero")
precondition(invertedDeltas(extreme, isContinuous: false, enabled: true) == ScrollDeltas(axis1: .min, axis2: -Int64.max, point1: 0, point2: 0, fixed1: 0, fixed2: 0), "overflow must not trap")
precondition(invertedDeltas(fractional, isContinuous: false, enabled: true) == ScrollDeltas(axis1: 3, axis2: -2, point1: 12, point2: -8, fixed1: 65536.5, fixed2: -131072.25), "fixed-point fraction survives")

let fixedNotch = ScrollDeltas(axis1: 0, axis2: 0, point1: 0, point2: 0, fixed1: 1, fixed2: 0)
let acceleratedNotch = ScrollDeltas(axis1: 0, axis2: 0, point1: 0, point2: 0, fixed1: -2.5, fixed2: 0)
let lineNotch = ScrollDeltas(axis1: -2, axis2: 0, point1: 0, point2: 0, fixed1: 0, fixed2: 0)
let pointNotch = ScrollDeltas(axis1: 0, axis2: 0, point1: 12, point2: 0, fixed1: 0, fixed2: 0)
precondition(pixelsForNotches(fixedNotch) == ScrollPixels(axis1: pixelsPerNotch, axis2: 0), "fixed delta is already lines")
precondition(pixelsForNotches(acceleratedNotch) == ScrollPixels(axis1: -2.5 * pixelsPerNotch, axis2: 0), "fixed delta keeps acceleration")
precondition(pixelsForNotches(lineNotch) == ScrollPixels(axis1: -2 * pixelsPerNotch, axis2: 0), "line delta fallback becomes pixels")
precondition(pixelsForNotches(pointNotch) == ScrollPixels(axis1: 12, axis2: 0), "point delta is already pixels")
let bothNotches = ScrollDeltas(axis1: -3, axis2: 2, point1: 0, point2: 0, fixed1: 0, fixed2: 0)
precondition(pixelsForNotches(bothNotches) == ScrollPixels(axis1: -3 * pixelsPerNotch, axis2: 2 * pixelsPerNotch), "both axes convert")
precondition(easeStep(48) == 48 * smoothStepFraction, "ease step is a fixed fraction")
precondition(easeStep(0.5) == 0, "ease stops below one pixel")
precondition(easeStep(60, fraction: 0.25) == 15, "ease fraction is adjustable")
precondition(zoomDirection(fixedNotch) == 0, "no delta gives no zoom")
precondition(zoomDirection(ScrollDeltas(axis1: 1, axis2: 0, point1: 0, point2: 0, fixed1: 0, fixed2: 0)) == 1, "up zooms in")
precondition(zoomDirection(ScrollDeltas(axis1: -1, axis2: 0, point1: 0, point2: 0, fixed1: 0, fixed2: 0)) == -1, "down zooms out")
precondition(zoomDirection(ScrollDeltas(axis1: 0, axis2: 2, point1: 0, point2: 0, fixed1: 0, fixed2: 0)) == 1, "horizontal fallback zooms in")
precondition(shiftingVerticalToHorizontal(ScrollPixels(axis1: 48, axis2: 0), shift: true) == ScrollPixels(axis1: 0, axis2: 48), "shift moves vertical to horizontal")
precondition(shiftingVerticalToHorizontal(ScrollPixels(axis1: 48, axis2: 0), shift: false) == ScrollPixels(axis1: 48, axis2: 0), "without shift vertical stays")
precondition(shiftingVerticalToHorizontal(ScrollPixels(axis1: 48, axis2: 8), shift: true) == ScrollPixels(axis1: 48, axis2: 8), "shift keeps both axes")
precondition(shouldSmooth(bundleID: "com.x", excluded: ["com.x"], enabled: true) == false, "excluded app is not smoothed")
precondition(shouldSmooth(bundleID: "com.x", excluded: ["com.y"], enabled: true) == true, "other app is smoothed")
precondition(shouldSmooth(bundleID: "com.x", excluded: [], enabled: false) == false, "disabled smooth is off")
precondition(shouldSmooth(bundleID: nil, excluded: ["com.x"], enabled: true) == true, "unknown app is smoothed")

print("scroll logic ok")
EOF
swiftc -O reMouse/ScrollInverter.swift "$tmp/main.swift" -o "$tmp/check"
"$tmp/check"
