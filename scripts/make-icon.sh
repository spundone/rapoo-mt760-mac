#!/bin/sh
# Renders Resources/AppIcon.icns from the SwiftUI icon (AppIconArt.swift).
set -eu
cd "$(dirname "$0")/.."
swift build
SET=$(mktemp -d)/AppIcon.iconset
.build/debug/MTControl --render-icon "$SET"
iconutil -c icns "$SET" -o Resources/AppIcon.icns
cp "$SET/icon_512x512@2x.png" Resources/AppIcon-1024.png
echo "Wrote Resources/AppIcon.icns"
