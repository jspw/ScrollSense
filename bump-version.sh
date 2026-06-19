#!/usr/bin/env bash
#
# Bump the version in source before cutting a release.
# Usage: ./bump-version.sh <version>     e.g. ./bump-version.sh 1.1.0
#
# Updates the one version string that lives in source: the CLI `version:` in
# ScrollSense.swift (which release-homebrew.sh verifies must match the tag).
#
#   - The menu-bar app version is stamped at build time by release.sh / build-dmg.sh.
#   - The Homebrew formula (url + sha256 + assert) is updated by
#     scripts/release-homebrew.sh, which needs the published tarball's checksum.
#
set -euo pipefail

VERSION="${1:?usage: ./bump-version.sh <version>   e.g. ./bump-version.sh 1.1.0}"
VERSION="${VERSION#v}"  # accept either 1.1.0 or v1.1.0

SWIFT="Sources/ScrollSense/ScrollSense.swift"

if ! grep -qE '^[[:space:]]*version: "[^"]+",' "$SWIFT"; then
  echo "ERROR: could not find the CLI version line in $SWIFT" >&2
  exit 1
fi

sed -i '' -E "s/(version: \")[^\"]+(\",)/\1${VERSION}\2/" "$SWIFT"
echo "Set CLI version to ${VERSION} in $SWIFT"

echo
echo "Next steps:"
echo "  1. Review & commit:   git commit -am \"Release v${VERSION}\""
echo "  2. App DMG release:   ./release.sh ${VERSION}"
echo "  3. Homebrew / CLI:    ./scripts/release-homebrew.sh ${VERSION}"
echo
echo "Either release script may run first — both reuse an existing v${VERSION} tag."
