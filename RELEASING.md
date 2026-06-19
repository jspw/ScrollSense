# Releasing ScrollSense

This is the maintainer runbook for shipping ScrollSense.

ScrollSense has two release surfaces:

| Artifact | Audience | Published through |
|----------|----------|-------------------|
| `ScrollSense-x.y.z.dmg` | Menu-bar app users | GitHub Releases |
| `scrollSense` CLI | Terminal/Homebrew users | Homebrew tap |

They can ship together or independently, but the version should match when both
are part of the same public release.

## One-Time Setup

```bash
./setup-signing.sh
gh auth login
```

Use the same signing identity for every app release when possible.
Accessibility permission is tied to the app's code signature; changing the
signing identity can force users to grant permission again.

The project currently uses a self-signed identity, not Apple notarization. That
means public DMG users must clear quarantine after install:

```bash
xattr -dr com.apple.quarantine /Applications/ScrollSense.app
```

## Version Sources

| Place | How it is set |
|-------|---------------|
| CLI version in `Sources/ScrollSense/ScrollSense.swift` | `./bump-version.sh` |
| App bundle `Info.plist` version | stamped by `./build-dmg.sh` / `./release.sh` |
| Homebrew formula URL, checksum, version assertion | `./scripts/release-homebrew.sh` |

## Pre-Release Checklist

Before tagging:

```bash
git status --short
swift test
swift run scrollSense --version
swift run scrollSense --help
```

Manual app smoke test:

```bash
./build-dmg.sh 2.2.0
open build/ScrollSense-2.2.0.dmg
```

Then install the app, launch it, and verify:

- menu-bar icon appears,
- Accessibility prompt opens,
- app reaches the Active state after permission is granted,
- mouse and trackpad toggles save,
- active device updates when scrolling,
- Launch at login toggle does not throw,
- CLI daemon warning appears if `scrollSense start` is running.

CLI smoke test:

```bash
swift run scrollSense set --mouse false --trackpad true
swift run scrollSense status
swift run scrollSense run --debug
```

Stop the foreground run with `Ctrl+C`.

## Standard Release Flow

Replace `2.2.0` with the version being shipped.

1. Land the feature/fix commits.

2. Bump the CLI source version:

   ```bash
   ./bump-version.sh 2.2.0
   git diff
   git commit -am "Release v2.2.0"
   ```

3. Publish the menu-bar app DMG:

   ```bash
   ./release.sh 2.2.0
   ```

   This builds the app, signs it, packages a DMG, and creates or updates the
   GitHub release.

4. Publish the CLI formula:

   ```bash
   ./scripts/release-homebrew.sh 2.2.0 --tap-dir ../homebrew-scrollsense
   ```

   This verifies the CLI version, creates or reuses the tag, computes the
   tarball checksum, updates `Formula/scrollsense.rb`, and optionally syncs the
   formula into the tap repo.

Either release script may run first. Both know how to reuse an existing
`v2.2.0` tag.

## Post-Release Verification

Verify GitHub release:

```bash
gh release view v2.2.0
curl -I https://github.com/jspw/ScrollSense/releases/download/v2.2.0/ScrollSense-2.2.0.dmg
```

Verify Homebrew:

```bash
brew update
brew upgrade scrollsense
scrollSense --version
brew test scrollsense
```

Verify a fresh app install:

```bash
open build/ScrollSense-2.2.0.dmg
```

Install to Applications, clear quarantine if needed, launch, and confirm the app
still gets Accessibility permission with the expected signing identity.

## Release Notes

The generated GitHub release notes include install instructions. Add a short
human-facing section before announcing:

```markdown
### What's changed
- ...
- ...

### Notes
- Current builds are self-signed and require clearing quarantine after install.
- Run either the menu-bar app or CLI daemon, not both.
```

Good release notes should emphasize user-visible behavior first, then technical
changes.

## Build Without Publishing

```bash
./build-app.sh
./build-dmg.sh 2.2.0
brew install --build-from-source ./Formula/scrollsense.rb
brew test scrollsense
```

## Failure Recovery

If `release.sh` succeeds but Homebrew release fails:

- keep the GitHub release,
- fix the formula issue,
- rerun `./scripts/release-homebrew.sh 2.2.0 --tap-dir ../homebrew-scrollsense`.

If the Homebrew script creates the tag but the tarball is not available yet:

- wait a minute for GitHub archive generation,
- rerun the same command.

If users lose Accessibility permission after updating:

- confirm the signing identity changed,
- ask users to remove the old ScrollSense entry from Accessibility,
- relaunch the app and grant permission again.
