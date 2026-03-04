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

# Install built binary
cp .build/release/scrollSense /usr/local/bin/
```

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
| `ScrollController.swift` | Reads/writes `com.apple.swipescrolldirection` via `CFPreferencesSetValue` + `CFPreferencesSynchronize` |
| `ConfigManager.swift` | Loads/saves `~/.scrollsense.json` user preferences |
| `StateManager.swift` | Tracks last applied state to skip redundant preference writes |
| `PIDManager.swift` | Manages `/tmp/scrollsense.pid` to prevent multiple daemon instances |
| `LaunchAgentManager.swift` | Creates/removes macOS LaunchAgent for auto-start |
| `Logger.swift` | Structured logging with debug/info/warning/error levels |
| `Models.swift` | Data models for config, device state, daemon state |

### Event Flow

```
Scroll event → CGEventTap → DeviceDetector (continuous field) → StateManager (changed?) → applyQueue.async → ScrollController (CFPreferences API)
```

Setting changes are dispatched to a background serial queue (`applyQueue`) so the event handler returns immediately without ever blocking scroll delivery.

## Key Implementation Details

- **Device detection heuristic**: `CGEventField.scrollWheelEventIsContinuous == 1` means trackpad (momentum/continuous), `0` means mouse (discrete steps)
- **Applying system setting**: `CFPreferencesSetValue` + `CFPreferencesSynchronize` on `kCFPreferencesAnyApplication` / `kCFPreferencesCurrentUser` / `kCFPreferencesAnyHost` — no subprocess spawning, no system-wide side effects
- **Optimization**: `StateManager` compares desired vs. last-applied setting and records optimistically (before the async write) to prevent duplicate dispatches on burst events
- **Async apply**: `ScrollDaemon.applyQueue` is a serial `DispatchQueue`; `recordAppliedValue()` is called on the event thread before dispatch to keep state consistent
- **Config file**: `~/.scrollsense.json` — stores per-device preferences
- **Accessibility permission** is required for `CGEventTap` to function (System Settings → Privacy & Security → Accessibility)

## Testing

Tests use the native Swift Testing framework (no external deps). Coverage includes Models, StateManager, ConfigManager, and DaemonState lifecycle. See [Tests/ScrollSenseTests/ScrollSenseTests.swift](Tests/ScrollSenseTests/ScrollSenseTests.swift).
