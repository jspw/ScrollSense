# ScrollSense

### Intelligent Natural Scroll Switching for macOS

---

## Overview

**ScrollSense** is a lightweight macOS daemon that automatically switches the system's Natural Scrolling behavior based on the active input device — mouse or trackpad.

macOS uses a single global setting for natural scrolling. However, many users prefer:

* ✅ Natural scrolling **ON** for trackpad
* ❌ Natural scrolling **OFF** for mouse

ScrollSense intelligently detects which device is currently being used and dynamically updates the system preference — giving users the correct scrolling behavior automatically.

No manual toggling. No friction. No System Settings visits.

---

## The Problem

macOS treats scrolling direction as a global setting:

```
System Settings → Trackpad / Mouse → Natural Scrolling
```

But in reality:

* Trackpad scrolling feels natural when enabled
* Mouse wheel scrolling feels inverted when enabled
* Switching between devices requires manual toggling
* This becomes extremely frustrating for developers and power users

There is no native per-device solution.

---

## The Solution

ScrollSense runs as a background daemon that:

1. Listens to low-level input events (scroll wheel) via `CGEventTap`
2. Detects whether the event originated from an external mouse or trackpad
3. Compares the detected device with user-defined preferences
4. Updates macOS natural scrolling **only if needed**
5. Avoids redundant system calls through internal state tracking

It simulates per-device scroll preferences — even though macOS does not support it natively.

---

## Installation

### Homebrew (Published Tap)

```bash
brew tap jspw/scrollsense
brew install scrollsense
```

### Homebrew (Local Formula Test)

Use this when you want to validate the formula from this repo before publishing it to your tap:

```bash
brew install --build-from-source ./Formula/scrollsense.rb
brew test scrollsense
```

### Run from Source Checkout

```bash
git clone https://github.com/jspw/ScrollSense.git
cd ScrollSense

# Run directly from the repo
swift run scrollSense --help
swift run scrollSense set --mouse false --trackpad true
swift run scrollSense run --debug
```

### Build Release Binary

```bash
git clone https://github.com/jspw/ScrollSense.git
cd ScrollSense

swift build -c release
./.build/release/scrollSense --help
./.build/release/scrollSense set --mouse false --trackpad true
./.build/release/scrollSense run --debug
```

Optional local install:

```bash
install -m 755 .build/release/scrollSense /usr/local/bin/scrollSense
```

### Permissions Required

ScrollSense requires **Accessibility** permission to monitor input events:

1. Open **System Settings → Privacy & Security → Accessibility**
2. Add your terminal app (e.g., Terminal, iTerm2) or the `scrollSense` binary
3. Toggle the permission ON

This is required only once during setup.

---

## Usage

If you are running from the repository without installing the binary, replace `scrollSense` with `swift run scrollSense`.

### Set Preferences

Define your preferred scroll behavior per device:

```bash
scrollSense set --mouse false --trackpad true
```

This saves to `~/.scrollsense.json`:

```json
{
  "mouseNatural" : false,
  "trackpadNatural" : true
}
```

### Start Daemon (Foreground / Debug Mode)

```bash
scrollSense run --debug
```

Prints real-time debug output:

```
[scrollSense] scrollSense daemon starting...
[scrollSense DEBUG 2024-01-15T10:30:00Z] Initial system natural scroll: true
[scrollSense DEBUG 2024-01-15T10:30:00Z] Config: mouse=false, trackpad=true
[scrollSense] scrollSense daemon running. Listening for scroll events...
[scrollSense] Debug mode enabled. Press Ctrl+C to stop.
[scrollSense DEBUG 2024-01-15T10:30:05Z] Device switch: none → mouse
[scrollSense DEBUG 2024-01-15T10:30:05Z] Applying scroll change: natural=false (for Mouse)
```

### Start Daemon (Background)

```bash
scrollSense start
```

This launches the daemon as a background process and tracks it via a PID file (`/tmp/scrollsense.pid`).

### Stop Daemon

```bash
scrollSense stop
```

Sends SIGTERM to the running daemon and cleans up the PID file.

### Run Daemon (Foreground)

For manual/interactive use without backgrounding:

```bash
scrollSense run
```

Or install as a LaunchAgent for auto-start at login:

```bash
scrollSense install
```

### Check Status

```bash
scrollSense status
```

Output:

```
  scrollSense Status
  ──────────────────────────────────
  Daemon: Running (PID: 12345)
  Mouse natural scroll: OFF
  Trackpad natural scroll: ON
  System natural scroll: OFF
  Config file: /Users/you/.scrollsense.json
  LaunchAgent installed: No
  ──────────────────────────────────
```

### Install LaunchAgent (Auto-Start at Login)

```bash
scrollSense install
```

To specify a custom binary path:

```bash
scrollSense install --path /usr/local/bin/scrollSense
```

### Uninstall LaunchAgent

```bash
scrollSense uninstall
```

---

## Architecture

ScrollSense is built natively using Swift and macOS system frameworks.

### Project Structure

```
Sources/
├── ScrollSense/              # Core library (ScrollSenseCore)
│   ├── Models.swift          # InputDevice, ScrollPreferences, DaemonState
│   ├── ConfigManager.swift   # Preferences storage (~/.scrollsense.json)
│   ├── DeviceDetector.swift  # CGEvent-based device detection
│   ├── ScrollController.swift # System scroll setting read/write
│   ├── StateManager.swift    # Runtime state & optimization
│   ├── ScrollDaemon.swift    # Main event loop & switching logic
│   ├── PIDManager.swift      # PID file tracking for daemon state
│   ├── LaunchAgentManager.swift # LaunchAgent install/uninstall
│   ├── Logger.swift          # Logging utility
│   └── ScrollSense.swift     # CLI command definitions
├── ScrollSenseApp/
│   └── main.swift            # Executable entry point
Tests/
└── ScrollSenseTests/
    └── ScrollSenseTests.swift # Unit tests (Swift Testing)
```

### Module Responsibilities

| Module | Responsibility |
|--------|---------------|
| **Models** | Data types: `InputDevice`, `ScrollPreferences`, `DaemonState` |
| **ConfigManager** | Load/save preferences from `~/.scrollsense.json` |
| **DeviceDetector** | Detect mouse vs trackpad from `CGEvent` fields |
| **ScrollController** | Read/write macOS `com.apple.swipescrolldirection` via CoreFoundation `CFPreferences` API |
| **StateManager** | Track runtime state, optimize by avoiding redundant writes |
| **ScrollDaemon** | Main event tap loop, orchestrates detection → comparison → update |
| **PIDManager** | PID file tracking (`/tmp/scrollsense.pid`) for daemon lifecycle |
| **LaunchAgentManager** | Install/uninstall macOS LaunchAgent for auto-start |
| **Logger** | Structured logging with debug/info/warning/error levels |

---

## Optimized Runtime Logic

```
On daemon start:
  → Load config
  → Read current system scroll state
  → Wait for first input event

On scroll event:
  If desired_setting == last_applied_setting
    → Do nothing (skip)
  Else
    → Update macOS scroll direction
    → Record new applied state

On device switch:
  → Log the switch (debug mode)
  → Evaluate if scroll change is needed
```

This ensures:

* ✅ No repeated system writes
* ✅ No unnecessary preference API calls
* ✅ Setting changes dispatched asynchronously — zero scroll lag
* ✅ No system-wide side effects (no process kills)

---

## Device Detection

ScrollSense uses the `CGEvent` field `.scrollWheelEventIsContinuous` to distinguish devices:

| Value | Device | Description |
|-------|--------|-------------|
| `1` | Trackpad | Continuous/momentum scrolling |
| `0` | Mouse | Discrete scroll wheel steps |

Additional fields available for debug inspection:

* `scrollWheelEventMomentumPhase`
* `scrollWheelEventScrollPhase`
* `scrollWheelEventDeltaAxis1` (vertical)
* `scrollWheelEventDeltaAxis2` (horizontal)

---

## Example Scenario

**User preference:** Mouse → Natural OFF, Trackpad → Natural ON

| Step | Action | Result |
|------|--------|--------|
| 1 | User scrolling with trackpad | Natural ON (already set) |
| 2 | User grabs mouse, scrolls | ScrollSense detects mouse → Natural OFF applied |
| 3 | User continues using mouse | No checks performed (optimized) |
| 4 | User touches trackpad | Device switch detected → Natural ON applied |

Seamless. Invisible. Instant.

---

## Technical Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 5.9+ |
| Event Monitoring | CoreGraphics (`CGEventTap`) |
| System Preferences | CoreFoundation `CFPreferences` API (`com.apple.swipescrolldirection`) |
| CLI Framework | [Swift Argument Parser](https://github.com/apple/swift-argument-parser) |
| Build System | Swift Package Manager |
| Auto-Start | macOS LaunchAgent |
| Testing | Swift Testing framework |

No Electron. No UI frameworks. Pure native macOS.

---

## Command Reference

| Command | Description |
|---------|-------------|
| `scrollSense start` | Start daemon in the background |
| `scrollSense stop` | Stop the running daemon |
| `scrollSense run` | Run daemon in the foreground |
| `scrollSense run --debug` | Run daemon with verbose debug logging |
| `scrollSense set --mouse <bool> --trackpad <bool>` | Set per-device preferences |
| `scrollSense status` | Show current preferences, daemon state, and system state |
| `scrollSense install` | Install LaunchAgent for auto-start at login |
| `scrollSense install --path <path>` | Install with custom binary path |
| `scrollSense uninstall` | Remove LaunchAgent |
| `scrollSense --version` | Show version |
| `scrollSense --help` | Show help |

---

## Homebrew Maintenance

### Bump the Formula for a New Release

The easiest way is to use the release helper:

```bash
./scripts/release-homebrew.sh v1.0.1 --tap-dir ../homebrew-scrollsense
```

That script:

* downloads the GitHub release tarball for the tag
* computes the correct `sha256`
* updates [`Formula/scrollsense.rb`](./Formula/scrollsense.rb)
* copies the formula into your tap repo if you pass `--tap-dir`

### Manual Flow

1. Create and push a new git tag:

```bash
git tag v1.0.1
git push origin v1.0.1
```

2. Download the release tarball and compute its SHA-256:

```bash
curl -L https://github.com/jspw/ScrollSense/archive/refs/tags/v1.0.1.tar.gz -o /tmp/scrollsense-v1.0.1.tar.gz
shasum -a 256 /tmp/scrollsense-v1.0.1.tar.gz
```

3. Update [`Formula/scrollsense.rb`](./Formula/scrollsense.rb):

* Set `url` to the new tag tarball
* Set `sha256` to the checksum from `shasum -a 256`
* Update the version assertion in `test do` if needed

4. Verify the formula locally:

```bash
brew audit --strict ./Formula/scrollsense.rb
brew install --build-from-source ./Formula/scrollsense.rb
brew test scrollsense
scrollSense --version
```

### Script Options

```bash
./scripts/release-homebrew.sh v1.0.1
./scripts/release-homebrew.sh 1.0.1 --tap-dir ../homebrew-scrollsense
./scripts/release-homebrew.sh v1.0.1 --repo jspw/ScrollSense --tap-dir ../homebrew-scrollsense
```

The tag must already exist on GitHub before the script can download the tarball.

### Publish / Upload to Homebrew

If you publish through a separate tap repository such as `jspw/homebrew-scrollsense`:

1. Copy the updated [`Formula/scrollsense.rb`](./Formula/scrollsense.rb) into the tap repo under `Formula/scrollsense.rb`
2. Commit and push the formula change to the tap repo
3. Users can then upgrade with:

```bash
brew update
brew upgrade scrollsense
```

If this repository is your source of truth for the formula, keep `Formula/scrollsense.rb` updated here first and mirror the same file into the tap repo you publish from.

---

## Configuration

Preferences are stored in `~/.scrollsense.json`:

```json
{
  "mouseNatural" : false,
  "trackpadNatural" : true
}
```

The daemon reloads this file every 2 seconds, so changes made via `scrollSense set` are picked up automatically without restarting.

---

## Limitations

* macOS has only one global natural scroll setting
* ScrollSense dynamically switches it — it cannot set per-device simultaneously
* Requires Accessibility permission
* Requires macOS 12.0 (Monterey) or later

---

## Future Enhancements

* [ ] Menu bar app
* [ ] Device-specific sensitivity profiles
* [ ] GUI preference panel
* [x] Homebrew distribution
* [ ] Notarized binary
* [ ] Strict mode (periodic system preference verification)
* [ ] Per-device custom scroll speed
* [ ] Scroll usage statistics

---

## Target Users

* Developers
* Designers
* MacBook users with external mouse
* Power users
* Anyone switching between devices daily

---

## Vision

ScrollSense aims to feel like a native macOS behavior enhancement.

**Invisible. Instant. Reliable.**

It removes friction from daily workflow by intelligently adapting to the user's current input device.

---

## License

MIT

---

## One-Line Pitch

> ScrollSense is a native macOS daemon that automatically switches scroll direction based on whether you're using a mouse or trackpad.
