#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release-homebrew.sh <version> [--tap-dir <path>] [--repo <owner/name>] [--remote <name>] [--tap-remote <name>]

Examples:
  ./scripts/release-homebrew.sh v1.0.1
  ./scripts/release-homebrew.sh 1.0.1 --tap-dir ../homebrew-scrollsense
  ./scripts/release-homebrew.sh v1.0.1 --repo jspw/ScrollSense --tap-dir ../homebrew-scrollsense
  ./scripts/release-homebrew.sh v1.0.1 --remote origin --tap-dir ../homebrew-scrollsense
  ./scripts/release-homebrew.sh v1.0.1 --tap-dir ../homebrew-scrollsense --tap-remote origin

What it does:
  1. Creates a git tag for the requested version
  2. Pushes that tag to your git remote
  3. Downloads the GitHub tag tarball
  4. Computes its SHA-256
  5. Updates Formula/scrollsense.rb with the new url, sha256, and version test
  6. Commits and pushes the formula update in the source repo
  7. Optionally copies, commits, and pushes the formula into your Homebrew tap repo

Notes:
  - The source repo must be clean before the script will create the tag.
  - If you pass --tap-dir, the tap repo must also be clean before the script runs.
  - This script creates an annotated tag like v1.0.1 and pushes it to the configured remote.
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMULA_PATH="${ROOT_DIR}/Formula/scrollsense.rb"
REPO_SLUG="jspw/ScrollSense"
TAP_DIR=""
REMOTE_NAME="origin"
TAP_REMOTE_NAME="origin"

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
    --remote)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --remote" >&2
        exit 1
      fi
      REMOTE_NAME="$2"
      shift 2
      ;;
    --tap-remote)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --tap-remote" >&2
        exit 1
      fi
      TAP_REMOTE_NAME="$2"
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

require_clean_repo() {
  local repo_dir="$1"
  local repo_label="$2"

  if ! git -C "${repo_dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "${repo_label} is not a git repository: ${repo_dir}" >&2
    exit 1
  fi

  if [[ -n "$(git -C "${repo_dir}" status --porcelain)" ]]; then
    echo "${repo_label} is not clean. Commit or stash your changes before releasing." >&2
    exit 1
  fi
}

if [[ "${VERSION_ARG}" == v* ]]; then
  TAG_VERSION="${VERSION_ARG}"
  PLAIN_VERSION="${VERSION_ARG#v}"
else
  TAG_VERSION="v${VERSION_ARG}"
  PLAIN_VERSION="${VERSION_ARG}"
fi

require_clean_repo "${ROOT_DIR}" "Source repo"

if ! git -C "${ROOT_DIR}" remote get-url "${REMOTE_NAME}" >/dev/null 2>&1; then
  echo "Git remote not found: ${REMOTE_NAME}" >&2
  exit 1
fi

if [[ -n "${TAP_DIR}" ]]; then
  TAP_DIR="$(cd "${TAP_DIR}" && pwd)"
  require_clean_repo "${TAP_DIR}" "Tap repo"

  if ! git -C "${TAP_DIR}" remote get-url "${TAP_REMOTE_NAME}" >/dev/null 2>&1; then
    echo "Tap git remote not found: ${TAP_REMOTE_NAME}" >&2
    exit 1
  fi
fi

if git -C "${ROOT_DIR}" rev-parse -q --verify "refs/tags/${TAG_VERSION}" >/dev/null 2>&1; then
  echo "Tag already exists locally: ${TAG_VERSION}" >&2
  exit 1
fi

if git -C "${ROOT_DIR}" ls-remote --exit-code --tags "${REMOTE_NAME}" "refs/tags/${TAG_VERSION}" >/dev/null 2>&1; then
  echo "Tag already exists on remote ${REMOTE_NAME}: ${TAG_VERSION}" >&2
  exit 1
fi

echo "Creating git tag:"
echo "  ${TAG_VERSION}"
git -C "${ROOT_DIR}" tag -a "${TAG_VERSION}" -m "Release ${TAG_VERSION}"

echo "Pushing git tag to ${REMOTE_NAME}:"
echo "  ${TAG_VERSION}"
git -C "${ROOT_DIR}" push "${REMOTE_NAME}" "${TAG_VERSION}"

TARBALL_URL="https://github.com/${REPO_SLUG}/archive/refs/tags/${TAG_VERSION}.tar.gz"
TMP_TARBALL="$(mktemp "/tmp/scrollsense-${PLAIN_VERSION}.XXXXXX.tar.gz")"

cleanup() {
  rm -f "${TMP_TARBALL}"
}
trap cleanup EXIT

echo "Downloading release tarball:"
echo "  ${TARBALL_URL}"

download_ok=0
for _ in 1 2 3 4 5; do
  if curl -fL "${TARBALL_URL}" -o "${TMP_TARBALL}"; then
    download_ok=1
    break
  fi
  sleep 2
done

if [[ "${download_ok}" -ne 1 ]]; then
  echo "" >&2
  echo "Failed to download the release tarball after pushing the tag." >&2
  echo "GitHub may not have published the archive yet. Retry in a moment." >&2
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

echo "Committing formula update in source repo"
git -C "${ROOT_DIR}" add "Formula/scrollsense.rb"
git -C "${ROOT_DIR}" commit -m "Update Homebrew formula for ${TAG_VERSION}"

echo "Pushing source repo commit to ${REMOTE_NAME}"
git -C "${ROOT_DIR}" push "${REMOTE_NAME}" HEAD

if [[ -n "${TAP_DIR}" ]]; then
  mkdir -p "${TAP_DIR}/Formula"
  cp "${FORMULA_PATH}" "${TAP_DIR}/Formula/scrollsense.rb"
  echo "Copied formula to tap repo:"
  echo "  ${TAP_DIR}/Formula/scrollsense.rb"

  echo "Committing formula update in tap repo"
  git -C "${TAP_DIR}" add "Formula/scrollsense.rb"
  git -C "${TAP_DIR}" commit -m "scrollsense ${PLAIN_VERSION}"

  echo "Pushing tap repo commit to ${TAP_REMOTE_NAME}"
  git -C "${TAP_DIR}" push "${TAP_REMOTE_NAME}" HEAD
fi

echo ""
echo "Release automation completed."
echo "Next steps:"
echo "  1. Run Homebrew verification if you want an extra confidence check"
if [[ -n "${TAP_DIR}" ]]; then
  echo "  2. Verify the published tap update with brew update && brew upgrade scrollsense"
else
  echo "  2. Copy Formula/scrollsense.rb into your tap repo if you publish from a separate repository"
fi
echo ""
echo "Suggested commands:"
echo "  brew audit --strict ./Formula/scrollsense.rb"
echo "  brew install --build-from-source ./Formula/scrollsense.rb"
echo "  brew test scrollsense"
if [[ -n "${TAP_DIR}" ]]; then
  echo "  brew update && brew upgrade scrollsense"
fi
