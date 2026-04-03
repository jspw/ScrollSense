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

section() {
  printf '\n==> %s\n' "$1"
}

info() {
  printf 'ℹ️  %s\n' "$1"
}

success() {
  printf '✅ %s\n' "$1"
}

warn_msg() {
  printf '⚠️  %s\n' "$1" >&2
}

error_msg() {
  printf '❌ %s\n' "$1" >&2
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMULA_PATH="${ROOT_DIR}/Formula/scrollsense.rb"
CLI_PATH="${ROOT_DIR}/Sources/ScrollSense/ScrollSense.swift"
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
        error_msg "Missing value for --tap-dir"
        exit 1
      fi
      TAP_DIR="$2"
      shift 2
      ;;
    --repo)
      if [[ $# -lt 2 ]]; then
        error_msg "Missing value for --repo"
        exit 1
      fi
      REPO_SLUG="$2"
      shift 2
      ;;
    --remote)
      if [[ $# -lt 2 ]]; then
        error_msg "Missing value for --remote"
        exit 1
      fi
      REMOTE_NAME="$2"
      shift 2
      ;;
    --tap-remote)
      if [[ $# -lt 2 ]]; then
        error_msg "Missing value for --tap-remote"
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
      error_msg "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "${FORMULA_PATH}" ]]; then
  error_msg "Formula not found: ${FORMULA_PATH}"
  exit 1
fi

if [[ ! -f "${CLI_PATH}" ]]; then
  error_msg "CLI source not found: ${CLI_PATH}"
  exit 1
fi

require_clean_repo() {
  local repo_dir="$1"
  local repo_label="$2"

  if ! git -C "${repo_dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    error_msg "${repo_label} is not a git repository: ${repo_dir}"
    exit 1
  fi

  if [[ -n "$(git -C "${repo_dir}" status --porcelain)" ]]; then
    error_msg "${repo_label} is not clean."
    info "Commit or stash your changes before releasing."
    exit 1
  fi
}

extract_cli_version() {
  ruby - "${CLI_PATH}" <<'RUBY'
path = ARGV[0]
content = File.read(path)
match = content.match(/^\s*version: "([^"]+)",$/)

if match
  puts match[1]
else
  warn "Could not determine current CLI version from #{path}"
  exit 1
end
RUBY
}

if [[ "${VERSION_ARG}" == v* ]]; then
  TAG_VERSION="${VERSION_ARG}"
  PLAIN_VERSION="${VERSION_ARG#v}"
else
  TAG_VERSION="v${VERSION_ARG}"
  PLAIN_VERSION="${VERSION_ARG}"
fi

require_clean_repo "${ROOT_DIR}" "Source repo"

CURRENT_CLI_VERSION="$(extract_cli_version)"
section "Release Prep"
if [[ "${CURRENT_CLI_VERSION}" == "${PLAIN_VERSION}" ]]; then
  success "Version check passed: current CLI version matches requested tag (${CURRENT_CLI_VERSION})"
else
  warn_msg "Version check mismatch: current CLI version is ${CURRENT_CLI_VERSION}, requested tag is ${PLAIN_VERSION}"
fi

if ! git -C "${ROOT_DIR}" remote get-url "${REMOTE_NAME}" >/dev/null 2>&1; then
  error_msg "Git remote not found: ${REMOTE_NAME}"
  exit 1
fi

if [[ -n "${TAP_DIR}" ]]; then
  TAP_DIR="$(cd "${TAP_DIR}" && pwd)"
  require_clean_repo "${TAP_DIR}" "Tap repo"

  if ! git -C "${TAP_DIR}" remote get-url "${TAP_REMOTE_NAME}" >/dev/null 2>&1; then
    error_msg "Tap git remote not found: ${TAP_REMOTE_NAME}"
    exit 1
  fi
fi

if git -C "${ROOT_DIR}" rev-parse -q --verify "refs/tags/${TAG_VERSION}" >/dev/null 2>&1; then
  error_msg "Tag already exists locally: ${TAG_VERSION}"
  exit 1
fi

if git -C "${ROOT_DIR}" ls-remote --exit-code --tags "${REMOTE_NAME}" "refs/tags/${TAG_VERSION}" >/dev/null 2>&1; then
  error_msg "Tag already exists on remote ${REMOTE_NAME}: ${TAG_VERSION}"
  exit 1
fi

info "Creating git tag ${TAG_VERSION}"
git -C "${ROOT_DIR}" tag -a "${TAG_VERSION}" -m "Release ${TAG_VERSION}"

info "Pushing git tag ${TAG_VERSION} to ${REMOTE_NAME}"
git -C "${ROOT_DIR}" push "${REMOTE_NAME}" "${TAG_VERSION}"

TARBALL_URL="https://github.com/${REPO_SLUG}/archive/refs/tags/${TAG_VERSION}.tar.gz"
TMP_TARBALL="$(mktemp "/tmp/scrollsense-${PLAIN_VERSION}.XXXXXX.tar.gz")"

cleanup() {
  rm -f "${TMP_TARBALL}"
}
trap cleanup EXIT

section "Tarball"
info "Downloading release tarball"
info "${TARBALL_URL}"

download_ok=0
for _ in 1 2 3 4 5; do
  if curl -fL "${TARBALL_URL}" -o "${TMP_TARBALL}"; then
    download_ok=1
    break
  fi
  sleep 2
done

if [[ "${download_ok}" -ne 1 ]]; then
  error_msg "Failed to download the release tarball after pushing the tag."
  info "GitHub may not have published the archive yet. Retry in a moment."
  exit 1
fi

SHA256="$(shasum -a 256 "${TMP_TARBALL}" | awk '{print $1}')"

success "Computed SHA-256"
info "${SHA256}"

ruby - "${CLI_PATH}" "${PLAIN_VERSION}" <<'RUBY'
path, version = ARGV
content = File.read(path)

original = content.dup
content.sub!(/^        version: ".*",$/, %{        version: "#{version}",})

if content == original
  STDERR.puts "CLI version was not updated. Expected version line was not found."
  exit 1
end

File.write(path, content)
RUBY

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
  STDERR.puts "Formula was not updated. Expected url/sha256/test lines were not found."
  exit 1
end

File.write(path, content)
RUBY

section "Source Updates"
success "Updated formula"
info "${FORMULA_PATH}"
success "Updated CLI version"
info "${CLI_PATH}"

info "Committing release metadata in source repo"
git -C "${ROOT_DIR}" add "Formula/scrollsense.rb" "Sources/ScrollSense/ScrollSense.swift"
git -C "${ROOT_DIR}" commit -m "Release ${TAG_VERSION}"

info "Pushing source repo commit to ${REMOTE_NAME}"
git -C "${ROOT_DIR}" push "${REMOTE_NAME}" HEAD

if [[ -n "${TAP_DIR}" ]]; then
  section "Tap Sync"
  mkdir -p "${TAP_DIR}/Formula"
  cp "${FORMULA_PATH}" "${TAP_DIR}/Formula/scrollsense.rb"
  success "Copied formula to tap repo"
  info "${TAP_DIR}/Formula/scrollsense.rb"

  info "Committing formula update in tap repo"
  git -C "${TAP_DIR}" add "Formula/scrollsense.rb"
  git -C "${TAP_DIR}" commit -m "scrollsense ${PLAIN_VERSION}"

  info "Pushing tap repo commit to ${TAP_REMOTE_NAME}"
  git -C "${TAP_DIR}" push "${TAP_REMOTE_NAME}" HEAD
fi

section "Done"
success "Release automation completed."
printf 'Next steps:\n'
printf '  1. Run Homebrew verification if you want an extra confidence check\n'
if [[ -n "${TAP_DIR}" ]]; then
  printf '  2. Verify the published tap update with brew update && brew upgrade scrollsense\n'
else
  printf '  2. Copy Formula/scrollsense.rb into your tap repo if you publish from a separate repository\n'
fi
printf '\nSuggested commands:\n'
printf '  brew audit --strict ./Formula/scrollsense.rb\n'
printf '  brew install --build-from-source ./Formula/scrollsense.rb\n'
printf '  brew test scrollsense\n'
if [[ -n "${TAP_DIR}" ]]; then
  printf '  brew update && brew upgrade scrollsense\n'
fi
