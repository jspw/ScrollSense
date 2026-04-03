#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release-homebrew.sh <version> [--tap-dir <path>] [--repo <owner/name>]

Examples:
  ./scripts/release-homebrew.sh v1.0.1
  ./scripts/release-homebrew.sh 1.0.1 --tap-dir ../homebrew-scrollsense
  ./scripts/release-homebrew.sh v1.0.1 --repo jspw/ScrollSense --tap-dir ../homebrew-scrollsense

What it does:
  1. Downloads the GitHub tag tarball for the requested version
  2. Computes its SHA-256
  3. Updates Formula/scrollsense.rb with the new url, sha256, and version test
  4. Optionally copies the formula into your Homebrew tap repo

Notes:
  - The git tag must already exist on GitHub before this script can download the tarball.
  - This script does not push commits for you. It prepares the formula so you can review and push.
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMULA_PATH="${ROOT_DIR}/Formula/scrollsense.rb"
REPO_SLUG="jspw/ScrollSense"
TAP_DIR=""

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

VERSION_ARG="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tap-dir)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --tap-dir" >&2
        exit 1
      fi
      TAP_DIR="$2"
      shift 2
      ;;
    --repo)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --repo" >&2
        exit 1
      fi
      REPO_SLUG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "${FORMULA_PATH}" ]]; then
  echo "Formula not found: ${FORMULA_PATH}" >&2
  exit 1
fi

if [[ "${VERSION_ARG}" == v* ]]; then
  TAG_VERSION="${VERSION_ARG}"
  PLAIN_VERSION="${VERSION_ARG#v}"
else
  TAG_VERSION="v${VERSION_ARG}"
  PLAIN_VERSION="${VERSION_ARG}"
fi

TARBALL_URL="https://github.com/${REPO_SLUG}/archive/refs/tags/${TAG_VERSION}.tar.gz"
TMP_TARBALL="$(mktemp "/tmp/scrollsense-${PLAIN_VERSION}.XXXXXX.tar.gz")"

cleanup() {
  rm -f "${TMP_TARBALL}"
}
trap cleanup EXIT

echo "Downloading release tarball:"
echo "  ${TARBALL_URL}"

if ! curl -fL "${TARBALL_URL}" -o "${TMP_TARBALL}"; then
  echo "" >&2
  echo "Failed to download the release tarball." >&2
  echo "Make sure tag ${TAG_VERSION} already exists on GitHub:" >&2
  echo "  git tag ${TAG_VERSION}" >&2
  echo "  git push origin ${TAG_VERSION}" >&2
  exit 1
fi

SHA256="$(shasum -a 256 "${TMP_TARBALL}" | awk '{print $1}')"

echo "Computed SHA-256:"
echo "  ${SHA256}"

ruby - "${FORMULA_PATH}" "${TARBALL_URL}" "${SHA256}" "${PLAIN_VERSION}" <<'RUBY'
path, url, sha, version = ARGV
content = File.read(path)

original = content.dup

content.sub!(/^  url ".*"$/, %{  url "#{url}"})
content.sub!(/^  sha256 ".*"$/, %{  sha256 "#{sha}"})
content.sub!(
  /^    assert_match ".*", shell_output\("\#\{bin\}\/scrollSense --version"\)$/,
  '    assert_match "' + version + '", shell_output("#{bin}/scrollSense --version")'
)

if content == original
  warn "Formula was not updated. Expected url/sha256/test lines were not found."
  exit 1
end

File.write(path, content)
RUBY

echo "Updated formula:"
echo "  ${FORMULA_PATH}"

if [[ -n "${TAP_DIR}" ]]; then
  TAP_DIR="$(cd "${TAP_DIR}" && pwd)"
  mkdir -p "${TAP_DIR}/Formula"
  cp "${FORMULA_PATH}" "${TAP_DIR}/Formula/scrollsense.rb"
  echo "Copied formula to tap repo:"
  echo "  ${TAP_DIR}/Formula/scrollsense.rb"
fi

echo ""
echo "Next steps:"
echo "  1. Review the formula diff"
echo "  2. Commit the formula change in this repo"
if [[ -n "${TAP_DIR}" ]]; then
  echo "  3. Commit and push the formula change in the tap repo"
else
  echo "  3. Copy Formula/scrollsense.rb into your tap repo and push it"
fi
echo ""
echo "Suggested commands:"
echo "  git diff -- Formula/scrollsense.rb"
if [[ -n "${TAP_DIR}" ]]; then
  echo "  (cd ${TAP_DIR} && git status --short && git add Formula/scrollsense.rb && git commit -m \"scrollsense ${PLAIN_VERSION}\" && git push)"
fi
