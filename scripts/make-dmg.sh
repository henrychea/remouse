#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

version="${VERSION:-1.0}"
build="${BUILD:-1}"
output="build/re-Mouse-${version}.dmg"
derived="build/dmg-derived"
app="$derived/Build/Products/Release/reMouse.app"
art="design/dmg"
venv="build/.venv"

xcodebuild -project reMouse.xcodeproj \
  -scheme reMouse \
  -configuration Release \
  -derivedDataPath "$derived" \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGN_STYLE=Manual \
  MARKETING_VERSION="$version" \
  CURRENT_PROJECT_VERSION="$build" \
  build

signature="$(codesign -dv "$app" 2>&1 || true)"
if ! grep -q "Signature=adhoc" <<<"$signature"; then
  echo "error: $app is not ad-hoc signed" >&2
  exit 1
fi

mkdir -p "$art"
swift scripts/make-dmg-bg.swift

if [[ ! -x "$venv/bin/dmgbuild" ]]; then
  python3 -m venv "$venv"
  "$venv/bin/pip" install --quiet --upgrade pip
  "$venv/bin/pip" install --quiet dmgbuild
fi

rm -f "$output"

"$venv/bin/dmgbuild" \
  -s scripts/dmg-settings.py \
  -D "app=$PWD/$app" \
  -D "icon=$PWD/$app/Contents/Resources/AppIcon.icns" \
  -D "background=$PWD/$art/background.png" \
  "reMouse" \
  "$output"

hdiutil verify "$output"
chmod 755 "$output"
grep "Signature=" <<<"$signature"
du -h "$output" | awk '{print $1"  "$2}'
