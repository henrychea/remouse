#!/bin/sh
set -eu
cd "$(dirname "$0")/../docs"
missing=0
for ref in $( { grep -oE '(src|href|poster|content)="[^"#][^"]*"' index.html | sed -E 's/^[a-z]+="([^"]*)"$/\1/'; grep -oE 'url\("[^"]+"\)' style.css | sed -E 's/url\("([^"]+)"\)/\1/'; } | grep -vE '^(https?:|mailto:|#)' | grep -E '\.[a-z0-9]+$' | sort -u); do
  [ "$ref" = "assets/demo.mp4" ] && continue
  [ -f "$ref" ] || { echo "missing: $ref"; missing=1; }
done
size=$(find . -type f ! -name demo.mp4 ! -name demo.gif -exec cat {} + | wc -c | awk '{print int($1/1024)}')
echo "docs size: ${size} KB"
[ "$size" -lt 1536 ] || { echo "docs over 1.5 MB"; missing=1; }
[ "$missing" -eq 0 ] && echo "ok"
exit "$missing"
