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

print("invert rule ok")
EOF
swiftc -O reMouse/ScrollInverter.swift "$tmp/main.swift" -o "$tmp/check"
"$tmp/check"
