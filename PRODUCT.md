# ScrollSense — Product Document

## The Problem

macOS enforces a single, global Natural Scrolling setting that applies to all input devices at once:

```
System Settings → Trackpad / Mouse → Natural Scrolling (on/off)
```

This creates a daily friction point for anyone who uses both a trackpad and an external mouse:

- **Trackpad users** expect natural scrolling (finger moves content, not viewport) — this is how Apple designed it
- **Mouse users** expect traditional scrolling (wheel rotates down = page moves down) — this is decades of muscle memory
- There is **no native per-device solution** in macOS

The only workaround is manually toggling the system setting every time you switch devices. For a developer or designer who frequently alternates between laptop trackpad and desktop mouse, this can happen dozens of times a day.

---

## The Solution

ScrollSense is a native macOS background daemon that:

1. Listens to low-level scroll events via `CGEventTap`
2. Detects whether each event came from a mouse or trackpad using the `scrollWheelEventIsContinuous` field
3. Compares the detected device against the user's stored preference
4. If the system setting already matches — does nothing
5. If it doesn't match — updates the system preference silently and instantly via the CoreFoundation `CFPreferences` API
6. Dispatches all setting changes asynchronously so scroll events are never delayed

The result: the correct scroll behavior is always active, automatically, without any user action.

---

## Core Design Principles

**Invisible.** The daemon runs silently in the background. Users should never think about it after the initial setup.

**Instant.** Preference changes are applied before the next scroll event is processed. There is no perceptible delay on device switch.

**Non-intrusive.** Uses a passive `CGEventTap` — scroll events pass through unmodified. Uses the native `CFPreferences` API — no subprocess spawning, no system-wide daemon restarts, no interference with other applications.

**Optimized.** The daemon tracks the last applied setting in memory and skips any write where the system is already in the correct state. On a typical session, the vast majority of scroll events result in zero system calls.

---

## How It Works

### Device Detection

The `CGEvent` scroll wheel event carries a field called `scrollWheelEventIsContinuous`:

| Value | Device | Behavior |
|-------|--------|----------|
| `1` | Trackpad | Continuous, momentum-based scrolling |
| `0` | Mouse | Discrete scroll wheel steps |

This field is set by macOS based on the physical device generating the event. It is the most reliable signal available without requiring USB/HID device enumeration or IOKit access.

### Setting Application

The system preference `com.apple.swipescrolldirection` in the global domain (`kCFPreferencesAnyApplication`) controls the natural scroll direction. ScrollSense reads and writes this value using the CoreFoundation `CFPreferences` API:

```
CFPreferencesSetValue  →  CFPreferencesSynchronize
```

This is the same mechanism macOS System Settings uses internally. It applies to the current user session immediately upon synchronization.

### State Optimization

On every scroll event:

1. `DeviceDetector` reads the `scrollWheelEventIsContinuous` field — O(1), no I/O
2. `StateManager` compares `desiredValue` against `lastAppliedScrollValue` — O(1), in-memory
3. If equal: returns early. No system call, no allocation, nothing.
4. If different: records the new value optimistically, dispatches the `CFPreferences` write to a background serial queue

The optimistic record (step 4 happens before the async write) prevents a burst of scroll events — which arrive faster than the write completes — from queuing up multiple redundant writes. Only the first event after a device switch triggers a write.

### Lifecycle

```
scrollSense start          # Spawns daemon as background process
scrollSense run --debug    # Runs in foreground with verbose logging
scrollSense stop           # Sends SIGTERM, graceful shutdown
scrollSense install        # Installs LaunchAgent for auto-start at login
scrollSense uninstall      # Removes LaunchAgent
scrollSense set --mouse false --trackpad true   # Set preferences
scrollSense status         # Show running state, current setting, config
```

Configuration is persisted to `~/.scrollsense.json` and reloaded by the daemon every 2 seconds, so preference changes via `scrollSense set` take effect without a daemon restart.

---

## User Setup

**Prerequisites:**
- macOS 12.0 (Monterey) or later
- Accessibility permission (one-time, required for `CGEventTap`)

**Setup:**
```bash
# Build
swift build -c release
cp .build/release/scrollSense /usr/local/bin/

# Set preferences (once)
scrollSense set --mouse false --trackpad true

# Auto-start at login
scrollSense install

# Start now
scrollSense start
```

After this, nothing else is required. The daemon runs silently and applies the correct scroll direction whenever the active input device changes.

---

## What Makes It Different

Most scroll direction switchers on macOS use one of these approaches:

| Approach | Problem |
|----------|---------|
| Menu bar app with manual toggle | Still requires user action |
| IOKit device polling | High CPU, battery drain, complex entitlements |
| Kernel extension | Deprecated in macOS, requires notarization |
| `defaults write` + `killall cfprefsd` | Kills system-wide preferences daemon, affects all apps |

ScrollSense uses `CGEventTap` (passive, low-level) + `CFPreferences` API (native, isolated) — the lightest possible approach that still achieves true automatic switching.

---

## Current Limitations

- macOS has one global natural scroll setting. ScrollSense switches it dynamically — it cannot hold two values simultaneously. There is a one-event lag on device switch (the first scroll event triggers detection and preference write; subsequent events see the updated setting).
- Requires Accessibility permission. This is unavoidable for any tool that observes input events without being the foreground app.
- Device detection relies on `scrollWheelEventIsContinuous`. Some Bluetooth mice may occasionally emit continuous-flagged events during inertial scrolling. This is uncommon but possible.

---

## Future Directions

| Feature | Notes |
|---------|-------|
| Menu bar status icon | Show current active device, quick preference toggle |
| Homebrew formula | `brew install scrollsense` distribution |
| Notarized binary | Required for distribution outside App Store |
| Scroll speed profiles | Per-device scroll speed/acceleration settings |
| Strict mode | Periodic verification that system setting hasn't drifted |
| GUI preference panel | SwiftUI settings window as alternative to CLI |
| Per-app overrides | Different behavior in specific applications |
| Usage statistics | Session summary: device switches, uptime |

---

## Technical Stack

| Component | Technology | Reason |
|-----------|-----------|--------|
| Language | Swift 5.9+ | Native macOS, no runtime overhead |
| Event monitoring | CoreGraphics `CGEventTap` | Only API for passive low-level input observation |
| Preference read/write | CoreFoundation `CFPreferences` | Native, isolated, no subprocess spawning |
| CLI | Swift Argument Parser | Type-safe, well-tested argument parsing |
| Build | Swift Package Manager | No Xcode project required |
| Auto-start | macOS LaunchAgent | Standard daemon lifecycle management |
| Tests | Swift Testing (native) | No external test dependencies |

No Electron. No UI frameworks. No interpreted runtime. Pure native macOS.

---

## Target Users

- Developers on MacBook with external mouse/monitor setup
- Designers alternating between trackpad gestures and precision mouse work
- Power users who refuse to manually toggle System Settings
- Anyone whose muscle memory for scroll direction differs between devices

---

## One-Line Pitch

> ScrollSense is a native macOS daemon that silently detects whether you're using a mouse or trackpad and automatically applies your preferred scroll direction — no manual toggling, no lag, no system interference.
