# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
# Build debug
swift build

# Build release
swift build -c release

# Run tests
swift test

# Run a single test (Swift Testing)
swift test --filter ScrollSenseTests/<TestName>

# Run daemon in foreground (debug mode)
swift run scrollSense run --debug

# One-time: create a stable signing cert so the Accessibility grant survives rebuilds
./setup-signing.sh

# Build, sign (with the stable cert if present, else ad-hoc), and install to /usr/local/bin
./install.sh
```

> Note: in some environments SwiftPM dependency fetch fails with
> `safe.bareRepository is 'explicit'`. Prefix builds with
> `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all`
> (this is what `install.sh` does).

## Project Overview

ScrollSense is a native macOS daemon (Swift) that automatically switches the system's Natural Scrolling setting based on whether the user is using a mouse or trackpad. macOS only has one global scroll direction setting, but users often prefer opposite behavior for each device type.

- **Language**: Swift 5.9+
- **Target**: macOS 12.0+
- **Build system**: Swift Package Manager
- **Key dependency**: `swift-argument-parser` v1.7.0 (CLI parsing)
- **Event system**: CoreGraphics `CGEventTap` + CoreFoundation `CFRunLoop`

## Architecture

Three-layer design:

**1. CLI Layer** — [Sources/ScrollSense/ScrollSense.swift](Sources/ScrollSense/ScrollSense.swift)
- Commands: `start`, `stop`, `run`, `set`, `status`, `install`, `uninstall`

**2. Daemon Core** — [Sources/ScrollSense/ScrollDaemon.swift](Sources/ScrollSense/ScrollDaemon.swift)
- Creates a `CGEventTap` to intercept scroll wheel events
- Runs a `CFRunLoop` to receive events continuously
- Reloads config every 2 seconds (not on every event)
- Handles SIGINT/SIGTERM for graceful shutdown

**3. Service Modules** — [Sources/ScrollSense/](Sources/ScrollSense/)

| File | Responsibility |
|------|---------------|
| `DeviceDetector.swift` | Analyzes `CGEvent.scrollWheelEventIsContinuous` (1=trackpad, 0=mouse) |
| `ScrollController.swift` | Reads `com.apple.swipescrolldirection` as the inversion baseline (`getCurrentNaturalScroll`). `setNaturalScroll` exists but is unused (see note below) |
| `CScrollHID` (C target, `Sources/CScrollHID/`) | Exposes private IOKit symbols (`CGEventCopyIOHIDEvent`, `IOHIDEventSetFloatValue`) to negate the embedded IOHID scroll values — required to reverse trackpad scrolling |
| `ConfigManager.swift` | Loads/saves `~/.scrollsense.json` user preferences |
| `StateManager.swift` | Tracks detected device + counters for status reporting |
| `PIDManager.swift` | Manages `/tmp/scrollsense.pid` to prevent multiple daemon instances |
| `LaunchAgentManager.swift` | Creates/removes macOS LaunchAgent for auto-start |
| `Logger.swift` | Structured logging with debug/info/warning/error levels |
| `Models.swift` | Data models for config, device state, daemon state |

### Event Flow

```
Scroll event → CGEventTap (.cgSessionEventTap, .tailAppendEventTap, .defaultTap)
  → DeviceDetector (continuous field)
  → if desired direction (config) != system baseline: invertScroll(event) in place
  → return (possibly modified) event
```

The tap is **active** (`.defaultTap`, tail-append) so it can modify events. The
callback runs synchronously and returns the modified event — there is no async
queue, because inversion must happen before the event is delivered.

## Approach: event inversion, NOT the global setting

ScrollSense does **not** change the macOS global natural-scroll setting. Writing
`com.apple.swipescrolldirection` (via `CFPreferences` or `defaults`) does **not**
take effect live on modern macOS — the change shows in System Settings but the
WindowServer keeps the old behavior until logout. (Verified on macOS 26.) So the
daemon instead intercepts each scroll event and **negates its deltas** for the
device whose desired direction differs from the current system baseline. This is
the same technique Scroll Reverser uses.

Consequence: the System Settings "Natural scrolling" checkbox is cosmetic while
the daemon runs — leave it alone. Behavior is driven entirely by event inversion.

## Key Implementation Details

- **Device detection heuristic**: `scrollWheelEventIsContinuous == 1` means trackpad (continuous), `0` means mouse (discrete)
- **Inversion is device-specific** (`ScrollDaemon.invertScroll`): a discrete mouse only needs its **line deltas** (`scrollWheelEventDeltaAxis1/2`) negated. A continuous trackpad additionally needs the **point deltas**, **fixed-point deltas**, and the **embedded IOHID scroll values** negated. Over-negating a mouse (touching point/fixed/IOHID) breaks it — keep the branch.
- **Baseline**: `getCurrentNaturalScroll()` reads the live system setting every 2s; inversion is applied only when `config.naturalScroll(for: device) != baseline`. Works regardless of which value the user's global setting is at.
- **Config file**: `~/.scrollsense.json` — stores per-device preferences
- **Accessibility permission** is required for `CGEventTap` to function (System Settings → Privacy & Security → Accessibility)
- **Code signing**: the Accessibility grant is keyed on the binary's code identity. SwiftPM's linker-signed ad-hoc signature changes every build, so macOS forgets the grant. Use `setup-signing.sh` (one-time, creates a stable self-signed cert) + `install.sh` (build, sign with that cert, install to `/usr/local/bin`) so the grant survives rebuilds.
- **`ScrollController.setNaturalScroll` is dead code** kept for reference — it writes the global setting, which is the approach that does NOT work live. Do not reintroduce it into the event flow.

## Testing

Tests use the native Swift Testing framework (no external deps). Coverage includes Models, StateManager, ConfigManager, and DaemonState lifecycle. See [Tests/ScrollSenseTests/ScrollSenseTests.swift](Tests/ScrollSenseTests/ScrollSenseTests.swift).
