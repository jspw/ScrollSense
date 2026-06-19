#!/usr/bin/env bash
#
# Build the ScrollSense menu-bar app into a signed .app bundle.
#
# SwiftPM produces a bare executable; a menu-bar (agent) app needs a real bundle
# with an Info.plist (LSUIElement) so it has no Dock icon, and a stable code
# signature so the Accessibility grant and Login Item survive rebuilds.
#
set -euo pipefail

APP_NAME="ScrollSense"
BUNDLE_ID="com.scrollsense.menubar"
EXEC="ScrollSenseBar"
BUILD_DIR=".build/release"
OUT_DIR="build"
APP_DIR="${OUT_DIR}/${APP_NAME}.app"
SIGN_ID="ScrollSense Self-Signed"
VERSION="${SCROLLSENSE_VERSION:-1.0.0}"

echo "==> Building menu-bar app..."
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all \
  swift build -c release --product "$EXEC"

echo "==> Assembling ${APP_DIR}..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/$EXEC" "$APP_DIR/Contents/MacOS/$EXEC"

ICON_LINE=""
if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
  ICON_LINE="  <key>CFBundleIconFile</key><string>AppIcon</string>"
fi

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>${EXEC}</string>
${ICON_LINE}
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

if security find-identity -v -p codesigning | grep -q "$SIGN_ID"; then
  echo "==> Signing with stable identity: $SIGN_ID"
  codesign --force --sign "$SIGN_ID" --identifier "$BUNDLE_ID" "$APP_DIR"
else
  echo "==> No stable identity found; ad-hoc signing."
  echo "    (Run ./setup-signing.sh once so the Accessibility grant survives rebuilds.)"
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_DIR"
fi

echo
echo "Built: $APP_DIR"
echo
echo "Install & run:"
echo "  cp -R \"$APP_DIR\" /Applications/   # may need: sudo cp -R ..."
echo "  open /Applications/${APP_NAME}.app"
echo
echo "Then grant Accessibility when prompted."
echo "NOTE: don't also run the CLI daemon (scrollSense run / the LaunchAgent) —"
echo "two invertors would cancel each other out. Use one or the other."
