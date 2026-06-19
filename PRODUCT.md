# ScrollSense Product Brief

## One-Line Positioning

ScrollSense gives macOS users per-device scroll direction: natural on the
trackpad, traditional on the mouse, automatically.

## Product Problem

macOS exposes Natural Scrolling as one global setting. That setting applies to
trackpads and mouse wheels together, even though people commonly expect opposite
behavior from each device.

For many users:

- Trackpad scrolling feels right when Natural Scrolling is on.
- Mouse-wheel scrolling feels right when Natural Scrolling is off.
- Switching between laptop, desk, and external-input setups creates repeated
  friction.
- The native workaround is manual: open System Settings and flip the same
  checkbox again.

This is small friction, but it happens in a high-frequency interaction. A scroll
direction mismatch is immediately visible, breaks flow, and makes the Mac feel
misconfigured.

## Target Users

Primary:

- MacBook users who dock at a desk and use an external mouse.
- Developers and designers who move between trackpad gestures and precision
  mouse work.
- Power users who already know which scroll direction they prefer per device.

Secondary:

- Users migrating from Windows or Linux who want traditional mouse-wheel
  behavior while keeping Apple's trackpad behavior.
- Open-source macOS users who prefer auditable native utilities over opaque
  background apps.

## Product Promise

Set your mouse and trackpad preferences once. ScrollSense quietly keeps each
device feeling right.

## What The Product Solves

ScrollSense solves the missing per-device layer on top of macOS' global Natural
Scrolling setting.

It lets a user say:

| Device | Desired behavior |
|--------|------------------|
| Mouse | Natural scrolling off |
| Trackpad | Natural scrolling on |

Then it applies that intent live as scroll events happen.

## What The Product Does Not Claim

ScrollSense does not:

- create a second native macOS preference,
- permanently split macOS' global Natural Scrolling setting,
- tune scroll speed or acceleration,
- identify every possible vendor-specific pointing device,
- avoid Accessibility permission.

The product is intentionally narrow: correct scroll direction per event, per
device class.

## Core Experience

### Menu-Bar App

The menu-bar app is the primary user experience.

It should feel like a small system utility:

- always available,
- quiet by default,
- visible only when needed,
- clear about permission state,
- clear about active device,
- safe to launch at login.

The dropdown contains only the controls users need:

- enable or pause ScrollSense,
- mouse natural-scroll preference,
- trackpad natural-scroll preference,
- launch at login,
- quit.

### CLI Daemon

The CLI is for users who want Homebrew, terminal setup, LaunchAgent lifecycle, or
debug output.

It supports:

- `set` for preferences,
- `run` for foreground usage,
- `start` and `stop` for background lifecycle,
- `install` and `uninstall` for LaunchAgent setup,
- `status` for inspection.

The app and CLI share the same underlying event-inversion engine. They should be
documented as alternative ways to run ScrollSense, not as separate products.

## Product Principles

**Invisible after setup.** The best session is one where the user forgets the app
is running.

**Honest about macOS constraints.** macOS has one global scroll setting.
ScrollSense corrects scroll events in flight; it does not pretend the OS has a
native per-device preference.

**Native first.** Swift, CoreGraphics, LaunchAgent/Login Item support, and local
configuration. No Electron, no telemetry, no cloud service.

**Fail legibly.** If Accessibility is missing, if the CLI and app are both
running, or if release builds are not notarized, users should see direct language
that explains what to do.

**Small surface area.** The project should stay focused on per-device scroll
direction before expanding into adjacent input customization.

## Technical Approach

ScrollSense uses an active `CGEventTap` to intercept scroll-wheel events and
modify them before delivery.

At runtime:

1. Load preferences from `~/.scrollsense.json`.
2. Read the current macOS Natural Scrolling value as the baseline.
3. Detect whether each scroll event is continuous (`trackpad`) or discrete
   (`mouse`).
4. Compare the device preference with the baseline.
5. If they differ, invert the event's scroll delta fields in place.
6. Pass the event on to the active application.

This approach is necessary because rewriting the global preference during active
scrolling is not reliable enough for modern macOS input behavior.

## Differentiation

| Alternative | User problem |
|-------------|--------------|
| Manual System Settings toggle | Interrupts work and must be repeated. |
| One global preference | One device always feels wrong. |
| Manual menu toggle utilities | Still require remembering to switch. |
| Preference-writing daemons | Can lag or fail to affect already-live input. |
| Heavy input managers | Larger surface area than this specific problem needs. |

ScrollSense is focused on one expectation: when the user scrolls, the active
device should behave the way they set it.

## Current Release State

- Native macOS menu-bar app.
- CLI daemon.
- Homebrew formula.
- MIT license.
- Self-signed DMG releases.
- Accessibility permission required.
- macOS 13+ target.

## Open-Source Release Goals

The public repository should make four things obvious:

1. What problem ScrollSense solves.
2. What permissions it needs and why.
3. How to install and use it safely.
4. How maintainers cut app and CLI releases.

The README should stay product-centric. Deeper technical details belong in
`docs/ARCHITECTURE.md`, and release-owner checklists belong in
`docs/OPEN_SOURCE_RELEASE.md` and `RELEASING.md`.

## Future Opportunities

Potential future work, in priority order:

1. Notarized releases, if an Apple Developer account is available.
2. More robust handling/reporting for smooth-scroll mice that look like
   trackpads.
3. Better first-run onboarding around Accessibility permission.
4. A visible troubleshooting panel for conflicts and stale TCC entries.
5. Optional scroll speed or acceleration controls, only if they do not dilute
   the product's core promise.
