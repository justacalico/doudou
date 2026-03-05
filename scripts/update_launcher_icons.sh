#!/usr/bin/env bash
# Regenerate all launcher icons from assets/icons/doudou.svg.
# Run from project root: ./scripts/update_launcher_icons.sh
set -e
cd "$(dirname "$0")/.."
if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
  echo "ImageMagick (magick or convert) required to convert SVG to PNG."
  exit 1
fi
if command -v magick >/dev/null 2>&1; then
  magick -background none -resize 1024x1024 -density 300 assets/icons/doudou.svg assets/icons/icon.png
elif command -v convert >/dev/null 2>&1; then
  convert -background none -resize 1024x1024 -density 300 assets/icons/doudou.svg assets/icons/icon.png
fi
if [ ! -f assets/icons/icon.png ]; then
  echo "Failed to generate icon.png"
  exit 1
fi
dart run flutter_launcher_icons
