#!/usr/bin/env bash
set -euo pipefail

repo="henrychea/remouse"

description='re:Mouse is a free macOS menu-bar app that reverses mouse-wheel scrolling while keeping trackpad and Magic Mouse gestures natural.'

topics=(
  macos
  swift
  swiftui
  mouse
  scroll
  scrolling
  scroll-reversal
  natural-scrolling
  menubar-app
  trackpad
  accessibility
  open-source
  mit-license
)

[ "${#description}" -le 350 ] || { echo "description is ${#description} chars, limit is 350" >&2; exit 1; }

args=(--homepage https://henrychea.github.io/remouse/)
for topic in "${topics[@]}"; do
  args+=(--add-topic "$topic")
done

gh repo edit "$repo" --description "$description" "${args[@]}"
