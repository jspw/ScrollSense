#!/usr/bin/env bash
#
# Package build/ScrollSense.app into a distributable .dmg.
# Usage: ./build-dmg.sh [version]   (version defaults to the app's Info.plist)
#
set -euo pipefail

APP_NAME="ScrollSense"
APP="build/${APP_NAME}.app"
VERSION="${1:-1.0.0}"

# Always rebuild so the app's embedded version matches the DMG name.
echo "==> Building app at version ${VERSION}..."
SCROLLSENSE_VERSION="$VERSION" ./build-app.sh

DMG="build/${APP_NAME}-${VERSION}.dmg"
STAGE="build/dmg-stage"

echo "==> Staging DMG contents..."
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating $DMG..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG" >/dev/null

rm -rf "$STAGE"
echo
echo "Built: $DMG"
echo "Open it to verify: open \"$DMG\""
