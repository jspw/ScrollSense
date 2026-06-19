# Open-Source Release Guide

This guide defines what should be ready before ScrollSense is presented as a
public open-source project.

## Release Objectives

A public release should make the project easy to evaluate:

- What problem does it solve?
- Why does it need Accessibility permission?
- How do I install it?
- What are the limitations?
- How can I build and inspect it myself?
- How does the maintainer cut a release?

## Public Repository Checklist

Required:

- `README.md` explains the product, problem, install paths, usage, privacy, and
  limitations.
- `PRODUCT.md` captures positioning, scope, target users, and product
  principles.
- `RELEASING.md` contains the maintainer release runbook.
- `docs/USER_GUIDE.md` covers setup and troubleshooting.
- `docs/ARCHITECTURE.md` explains the event-tap and inversion design.
- `LICENSE` is present and linked from the README.
- `assets/menu-bar.png` is used in the README.

Recommended before a broad announcement:

- Add `CHANGELOG.md` or keep GitHub release notes consistently updated.
- Add `CONTRIBUTING.md` with issue and pull-request expectations.
- Add issue templates for bug reports and device-detection reports.
- Add a short security/privacy note if users ask about Accessibility scope.
- Consider notarized builds when an Apple Developer account is available.

## Release Messaging

Use product-first language:

> ScrollSense gives macOS per-device scroll direction: natural on the trackpad,
> traditional on the mouse, automatically.

Avoid implying that ScrollSense creates a hidden native macOS per-device
preference. It does not. It corrects scroll events in flight.

Always mention:

- macOS has one global Natural Scrolling setting,
- ScrollSense requires Accessibility permission,
- current DMG builds are self-signed and require clearing quarantine,
- users should run either the app or CLI daemon, not both.

## README Standard

The README should answer in this order:

1. What is ScrollSense?
2. What issue does it solve?
3. What does the user get after installing it?
4. How do they install it?
5. How do they use it?
6. What permissions and limitations should they understand?
7. Where do technical readers go next?

Keep implementation detail short in the README. Move deeper explanations to
`docs/ARCHITECTURE.md`.

## Screenshot Guidance

Use real product imagery, not abstract diagrams.

Current asset:

```text
assets/menu-bar.png
```

The screenshot should show the actual menu-bar dropdown because that is the
primary product surface for most users.

Update the screenshot when:

- the menu layout changes,
- labels change,
- permission or conflict states change significantly,
- visual styling changes enough to make the README stale.

## Privacy And Permission Guidance

Accessibility permission can worry users. Be direct:

- ScrollSense needs Accessibility to observe and modify scroll events.
- It does not need network access.
- It does not collect analytics.
- It stores preferences locally.
- The source is available for inspection.

Do not bury this in technical sections. It belongs in the README and user guide.

## Release Artifact Expectations

GitHub release:

- contains `ScrollSense-x.y.z.dmg`,
- includes installation steps,
- calls out self-signed/not-notarized status,
- includes user-visible changes.

Homebrew release:

- formula URL points to the matching `vX.Y.Z` tarball,
- formula checksum is updated,
- formula test checks the matching CLI version,
- tap repository is pushed if publishing through a separate tap.

## Announcement Checklist

Before posting publicly:

```bash
swift test
./build-dmg.sh X.Y.Z
brew install --build-from-source ./Formula/scrollsense.rb
brew test scrollsense
```

Then verify manually:

- fresh app launch,
- Accessibility prompt,
- mouse and trackpad toggles,
- active device display,
- launch-at-login toggle,
- CLI `status`,
- CLI conflict warning in the app.

## Suggested Initial Announcement

```text
ScrollSense is an open-source macOS menu-bar utility that gives you per-device
scroll direction: natural on the trackpad, traditional on the mouse.

macOS only exposes one global Natural Scrolling setting, so ScrollSense corrects
scroll events live based on whether they came from a mouse or trackpad.

It is native Swift, MIT licensed, local-only, and available as a menu-bar app or
CLI daemon.
```
