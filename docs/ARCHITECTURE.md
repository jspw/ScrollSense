# ScrollSense Architecture

ScrollSense is a native macOS utility written in Swift. It has two user-facing
runtimes and one shared core.

## Runtime Surfaces

| Target | Role |
|--------|------|
| `ScrollSenseBar` | SwiftUI menu-bar app using `MenuBarExtra`. |
| `scrollSense` | CLI executable for daemon, LaunchAgent, and debugging workflows. |
| `ScrollSenseCore` | Shared config, detection, inversion, daemon, and CLI command logic. |
| `CScrollHID` | C shim for embedded IOHID scroll values used by trackpad events. |

## Source Layout

```text
Sources/
  ScrollSense/
    ConfigManager.swift
    DeviceDetector.swift
    LaunchAgentManager.swift
    Models.swift
    PIDManager.swift
    ScrollController.swift
    ScrollDaemon.swift
    ScrollEngine.swift
    ScrollInverter.swift
    ScrollSense.swift
    StateManager.swift
  ScrollSenseApp/
    main.swift
  ScrollSenseBar/
    MenuBarIcon.swift
    MenuPanelView.swift
    ScrollSenseBarApp.swift
    ScrollService.swift
  CScrollHID/
    CScrollHID.c
    include/CScrollHID.h
```

## Core Event Flow

```text
scroll event
  -> CGEventTap callback
  -> DeviceDetector.detectDevice
  -> config.naturalScroll(for: device)
  -> compare with system baseline
  -> ScrollInverter.invert(event), if needed
  -> return event to macOS
```

The global macOS Natural Scrolling value is treated as a baseline. If the active
device's desired behavior matches that baseline, ScrollSense passes the event
through unchanged. If it differs, ScrollSense flips the event deltas in place.

## Device Detection

`DeviceDetector` uses the `CGEvent` field:

```swift
.scrollWheelEventIsContinuous
```

Current mapping:

| Value | Device |
|-------|--------|
| `1` | Trackpad |
| `0` | Mouse |

This is intentionally lightweight. It avoids USB/HID enumeration and does not
need vendor-specific device access.

## Event Inversion

`ScrollInverter` handles mouse and trackpad events differently.

Mouse wheel events use line deltas:

- `scrollWheelEventDeltaAxis1`
- `scrollWheelEventDeltaAxis2`

Trackpad events also need precise fields:

- `scrollWheelEventPointDeltaAxis1`
- `scrollWheelEventPointDeltaAxis2`
- `scrollWheelEventFixedPtDeltaAxis1`
- `scrollWheelEventFixedPtDeltaAxis2`
- embedded IOHID scroll values through `CScrollHID`

The branch is important: flipping trackpad-only fields for mouse events can
break mouse scrolling.

## Menu-Bar App

`ScrollService` owns the bridge between SwiftUI and the core engine:

- starts `ScrollEngine` when Accessibility permission is available,
- publishes active device and running state,
- persists toggle changes through `ConfigManager`,
- registers/unregisters launch at login through `SMAppService`,
- checks whether the CLI daemon is already running through `PIDManager`.

`ScrollEngine` runs the event tap on a background thread so the SwiftUI app stays
responsive.

## CLI Daemon

`ScrollDaemon` owns a blocking run loop and PID lifecycle for terminal use. It:

- writes `/tmp/scrollsense.pid`,
- installs a `CGEventTap`,
- handles `SIGINT` and `SIGTERM`,
- reloads preferences every two seconds,
- refreshes the system baseline every two seconds,
- removes the PID file on shutdown.

`LaunchAgentManager` can install the CLI as:

```text
~/Library/LaunchAgents/com.scrollsense.daemon.plist
```

## Configuration

`ConfigManager` stores local preferences in:

```text
~/.scrollsense.json
```

Schema:

```json
{
  "enabled" : true,
  "mouseNatural" : false,
  "trackpadNatural" : true
}
```

The `enabled` field is backward-compatible. Older config files without this key
decode as enabled.

## System Baseline

`ScrollController.getCurrentNaturalScroll()` reads:

```text
com.apple.swipescrolldirection
```

from the global CoreFoundation preferences domain.

The current runtime does not depend on repeatedly writing this value for normal
operation. It reads the value so the event inverter knows which device
preferences already match the user's system baseline.

## Build Targets

```bash
swift build
swift test
swift run scrollSense --help
swift build -c release --product ScrollSenseBar
```

The app bundle is assembled by `build-app.sh` because SwiftPM builds an
executable, not a `.app` bundle.
