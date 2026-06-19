# ScrollSense

### Intelligent Natural Scroll Switching for macOS

---

## Overview

**ScrollSense** gives macOS per-device scroll direction: natural scrolling on the
trackpad, traditional on the mouse — automatically, based on whichever device you're
using right now.

macOS only has a single global natural-scroll setting. Most people who use both a
trackpad and a mouse want opposite behavior for each:

* ✅ Natural scrolling **ON** for trackpad
* ❌ Natural scrolling **OFF** for mouse

ScrollSense detects the active device on every scroll event and **inverts the scroll
direction in-flight** for the device that should behave opposite to your system
setting. It does **not** flip the global macOS setting (that doesn't apply live on
modern macOS) — it corrects the scroll itself, the same technique Scroll Reverser uses.

Ships two ways: a **menu-bar app** (no Terminal needed) and a **CLI daemon**.

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

ScrollSense runs an active `CGEventTap` that:

1. Intercepts each scroll-wheel event
2. Detects whether it came from a mouse or trackpad (`scrollWheelEventIsContinuous`)
3. Compares the device's desired direction (your preference) against the current system baseline
4. If they differ, **negates the event's scroll deltas in-place** so it scrolls the way you want
5. Returns the (possibly modified) event before it reaches the app

A discrete mouse only needs its line deltas flipped; a continuous trackpad also needs
its point, fixed-point, and embedded IOHID scroll values flipped. This delivers true
per-device behavior even though macOS has only one global setting.

> While ScrollSense runs, the System Settings "Natural scrolling" checkbox is cosmetic
> — leave it alone. Behavior is driven entirely by event inversion.

---

## Installation

### Menu Bar App (.dmg) — recommended

The easiest way to use ScrollSense: a menu-bar app with a dropdown for status and
per-device toggles. No Terminal needed after install.

1. Download the latest `ScrollSense-x.y.z.dmg` from [Releases](https://github.com/jspw/ScrollSense/releases) and open it.
2. Drag **ScrollSense** into Applications.
3. ScrollSense isn't notarized (no paid Apple Developer account), so macOS will say
   it "can't verify the developer." Clear the quarantine flag:
   ```bash
   xattr -dr com.apple.quarantine /Applications/ScrollSense.app
   ```
4. Launch it from Applications. A menu-bar icon appears — grant **Accessibility**
   when prompted (the icon reflects your active device once running).

> The menu-bar app and the CLI daemon both invert scroll events — run **one or the
> other**, not both, or the two inversions cancel out.

Build it yourself from source:

```bash
./setup-signing.sh   # one-time: stable cert so the Accessibility grant persists
./make-icon.sh       # generate the app icon
./build-dmg.sh       # produces build/ScrollSense-x.y.z.dmg
```

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

ScrollSense requires **Accessibility** permission to intercept scroll events:

1. Open **System Settings → Privacy & Security → Accessibility**
2. Enable the relevant entry:
   * **Menu-bar app:** `ScrollSense.app` (you'll be prompted on first launch)
   * **CLI:** the `scrollSense` binary, or the terminal app you run it from
3. Toggle the permission ON

This is required only once during setup. Signed builds keep the grant across updates.

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
[scrollSense DEBUG 2024-01-15T10:30:00Z] System natural scroll (baseline): true
[scrollSense DEBUG 2024-01-15T10:30:00Z] Config: mouse=false, trackpad=true
[scrollSense] scrollSense daemon running. Listening for scroll events...
[scrollSense] Debug mode enabled. Press Ctrl+C to stop.
[scrollSense DEBUG 2024-01-15T10:30:05Z] Device switch: none → mouse
[scrollSense DEBUG 2024-01-15T10:30:05Z] Inverting scroll for Mouse (desired natural=false, system=true)
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
├── ScrollSense/                # Core library (ScrollSenseCore)
│   ├── Models.swift            # InputDevice, ScrollPreferences, DaemonState
│   ├── ConfigManager.swift     # Preferences storage (~/.scrollsense.json)
│   ├── DeviceDetector.swift    # CGEvent-based device detection
│   ├── ScrollInverter.swift    # Negates scroll deltas (mouse vs trackpad fields)
│   ├── ScrollController.swift  # Reads the system natural-scroll baseline
│   ├── StateManager.swift      # Runtime state & counters
│   ├── ScrollDaemon.swift      # CLI daemon: blocking event-tap run loop
│   ├── ScrollEngine.swift      # Non-blocking tap engine for the menu-bar app
│   ├── PIDManager.swift        # PID file tracking for daemon state
│   ├── LaunchAgentManager.swift # LaunchAgent install/uninstall
│   ├── Logger.swift            # Logging utility
│   └── ScrollSense.swift       # CLI command definitions
├── CScrollHID/                 # C shim for private IOKit IOHID scroll symbols
├── ScrollSenseApp/
│   └── main.swift              # CLI executable entry point
└── ScrollSenseBar/             # Menu-bar app (SwiftUI MenuBarExtra)
    ├── ScrollSenseBarApp.swift # @main app + accessory activation policy
    ├── ScrollService.swift     # Engine + config + permission + login item
    ├── MenuPanelView.swift     # Dropdown panel UI
    └── MenuBarIcon.swift       # Device-aware template menu-bar icon
Tests/
└── ScrollSenseTests/
    └── ScrollSenseTests.swift  # Unit tests (Swift Testing)
```

### Module Responsibilities

| Module | Responsibility |
|--------|---------------|
| **Models** | Data types: `InputDevice`, `ScrollPreferences`, `DaemonState` |
| **ConfigManager** | Load/save preferences from `~/.scrollsense.json` |
| **DeviceDetector** | Detect mouse vs trackpad from `CGEvent` fields |
| **ScrollInverter** | Negate an event's scroll deltas — line deltas for a mouse; point/fixed/IOHID too for a trackpad |
| **ScrollController** | Read the system natural-scroll setting (`com.apple.swipescrolldirection`) as the inversion baseline |
| **StateManager** | Track runtime state and counters for status reporting |
| **ScrollDaemon** | CLI daemon: blocking `CGEventTap` run loop + PID/signals |
| **ScrollEngine** | Non-blocking tap engine the menu-bar app runs on a background thread |
| **CScrollHID** | C shim exposing private IOKit `IOHIDEvent` symbols to flip trackpad scroll |
| **PIDManager** | PID file tracking (`/tmp/scrollsense.pid`) for daemon lifecycle |
| **LaunchAgentManager** | Install/uninstall macOS LaunchAgent for auto-start |
| **Logger** | Structured logging with debug/info/warning/error levels |

The menu-bar app target (`ScrollSenseBar`) wraps `ScrollEngine` in a SwiftUI
`MenuBarExtra`; `ScrollInverter` is shared by both the CLI daemon and the app.

---

## Runtime Logic

```
On start:
  → Load config (~/.scrollsense.json)
  → Read the system natural-scroll baseline
  → Create an active CGEventTap (tail-append, session level)

On scroll event (synchronously, in the tap callback):
  → Detect device (continuous → trackpad, discrete → mouse)
  → desired = config.naturalScroll(for: device)
  If desired == baseline
    → pass the event through unchanged
  Else
    → negate the event's scroll deltas (device-specific fields)
    → return the modified event

Every 2s: reload config + re-read the baseline (cheap, off the hot path)
```

This ensures:

* ✅ Correct direction per device, applied live — no logout required
* ✅ No writes to system preferences, no `defaults`/process kills
* ✅ Inversion happens in the callback before delivery — no scroll lag
* ✅ Adapts to whatever your global natural-scroll setting is

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

Assume the system baseline is natural ON.

| Step | Action | Result |
|------|--------|--------|
| 1 | Scrolling with trackpad | Matches baseline → passed through → natural |
| 2 | Grabs mouse, scrolls | Detected as mouse → deltas inverted → traditional |
| 3 | Keeps using mouse | Every mouse event inverted, transparently |
| 4 | Touches trackpad | Detected as trackpad → passed through → natural |

Seamless. Invisible. Instant.

---

## Technical Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 5.9+ |
| Event interception | CoreGraphics (`CGEventTap`, active/`.defaultTap`) |
| Trackpad inversion | Private IOKit `IOHIDEvent` symbols via a small C shim |
| Menu-bar app | SwiftUI `MenuBarExtra` (macOS 13+) |
| CLI Framework | [Swift Argument Parser](https://github.com/apple/swift-argument-parser) |
| Build System | Swift Package Manager |
| Auto-Start | macOS LaunchAgent (CLI) / `SMAppService` Login Item (app) |
| Testing | Swift Testing framework |

No Electron. SwiftUI only for the menu bar. Pure native macOS.

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

* creates and pushes the git tag
* downloads the GitHub release tarball for the tag
* computes the correct `sha256`
* updates [`Formula/scrollsense.rb`](./Formula/scrollsense.rb)
* commits and pushes the formula update in this repo
* copies, commits, and pushes the formula into your tap repo if you pass `--tap-dir`

Your source repo must be clean before running it, since the script tags the current commit. If you pass `--tap-dir`, the tap repo must also be clean.

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
./scripts/release-homebrew.sh v1.0.1 --remote origin --tap-dir ../homebrew-scrollsense
./scripts/release-homebrew.sh v1.0.1 --tap-dir ../homebrew-scrollsense --tap-remote origin
```

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

* Requires **Accessibility** permission (needed for the event tap)
* The System Settings "Natural scrolling" checkbox is cosmetic while ScrollSense runs
* Run **one** invertor at a time — the menu-bar app and the CLI daemon would cancel each other out
* Device detection relies on `scrollWheelEventIsContinuous`; some smooth-scroll mouse drivers report as continuous and may be misdetected as a trackpad
* Requires macOS **13.0 (Ventura)** or later (the menu-bar app uses `MenuBarExtra`)

---

## Future Enhancements

* [x] Menu bar app
* [x] GUI preference panel (menu-bar dropdown)
* [x] Homebrew distribution
* [ ] Notarized binary (requires a paid Apple Developer account)
* [ ] Per-axis inversion (vertical only / horizontal only)
* [ ] Device-specific sensitivity / scroll speed
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

## Contributing

Contributions are welcome! To get started:

```bash
git clone https://github.com/jspw/ScrollSense.git
cd ScrollSense

swift build                       # build everything
swift test                        # run the test suite
swift run scrollSense run --debug # run the CLI daemon
./build-app.sh                    # build the menu-bar app bundle
```

Guidelines:

* Keep the shared inversion logic in `ScrollInverter` — both the CLI daemon and the
  menu-bar app depend on it. The mouse-vs-trackpad field branch is load-bearing; see
  the comments before changing it.
* The Accessibility grant is keyed to code signature — see `setup-signing.sh` and
  [CLAUDE.md](CLAUDE.md) for why a stable cert matters during development.
* Open an issue to discuss larger changes before sending a PR.

## Releasing

Maintainers: see **[RELEASING.md](RELEASING.md)** for the full version-bump and
release flow (menu-bar DMG + Homebrew CLI).

## License

[MIT](LICENSE)

---

## One-Line Pitch

> ScrollSense is a native macOS daemon that automatically switches scroll direction based on whether you're using a mouse or trackpad.
