#!/usr/bin/env bash
#
# Cut a GitHub release: build the signed app, package a DMG, and publish it.
# Usage: ./release.sh <version>     e.g. ./release.sh 1.1.0
#
# Requires the `gh` CLI, authenticated (gh auth login).
#
set -euo pipefail

VERSION="${1:?usage: ./release.sh <version>   e.g. ./release.sh 1.1.0}"
APP_NAME="ScrollSense"
TAG="v${VERSION}"
DMG="build/${APP_NAME}-${VERSION}.dmg"

command -v gh >/dev/null || {
  echo "gh CLI not found. Install: brew install gh"
  exit 1
}

echo "==> Building DMG for ${TAG}..."
./build-dmg.sh "$VERSION"

# Build release notes in a temp file (quoted heredoc = no expansion, backticks
# are literal), then fill in the version placeholders with sed.
NOTES="$(mktemp)"
trap 'rm -f "$NOTES"' EXIT
cat > "$NOTES" <<'NOTESEOF'
## ScrollSense __TAG__

Per-device scroll direction for macOS — natural on the trackpad, traditional on the mouse.

### Install
1. Download `__APP__-__VERSION__.dmg` below and open it.
2. Drag **__APP__** to Applications.
3. ScrollSense is not notarized, so clear the quarantine flag:
   ```
   xattr -dr com.apple.quarantine /Applications/__APP__.app
   ```
4. Launch it and grant **Accessibility** when prompted.
NOTESEOF

sed -i '' \
  -e "s/__TAG__/${TAG}/g" \
  -e "s/__APP__/${APP_NAME}/g" \
  -e "s/__VERSION__/${VERSION}/g" \
  "$NOTES"

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "==> Release ${TAG} already exists — uploading DMG (clobber)..."
  gh release upload "$TAG" "$DMG" --clobber
else
  echo "==> Creating GitHub release ${TAG}..."
  # Uses the existing git tag if one is already present (e.g. from
  # release-homebrew.sh), otherwise creates the tag at HEAD.
  gh release create "$TAG" "$DMG" \
    --title "${APP_NAME} ${TAG}" \
    --notes-file "$NOTES"
fi

echo
echo "Published: $TAG"
