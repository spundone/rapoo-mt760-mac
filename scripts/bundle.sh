#!/bin/sh
# Builds a release arm64 MT Control.app into dist/ and signs it (local identity, else ad-hoc).
set -eu
cd "$(dirname "$0")/.."
swift build -c release --arch arm64
APP=dist/"MT Control.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/arm64-apple-macosx/release/MTControl "$APP/Contents/MacOS/MTControl"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"
# A stable identity keeps macOS privacy grants (Input Monitoring) across rebuilds.
IDENTITY="${MTC_SIGN_IDENTITY:-MT Control Local Signing}"
if security find-identity -p codesigning | grep -q "$IDENTITY"; then SIGN="$IDENTITY"; else SIGN=-; fi
codesign --force --sign "$SIGN" --options runtime --entitlements Resources/MTControl.entitlements "$APP"
echo "Built $APP"
