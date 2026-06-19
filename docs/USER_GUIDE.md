# ScrollSense User Guide

This guide is for people installing and using ScrollSense.

## Choose One Runtime

ScrollSense can run as either:

- the **menu-bar app**, or
- the **CLI daemon**.

Use one at a time. If both are running, both can invert the same scroll event and
make scrolling appear unchanged or inconsistent.

## Recommended Setup

Most users should install the menu-bar app.

Recommended preference:

| Device | Setting |
|--------|---------|
| Mouse | Natural scrolling off |
| Trackpad | Natural scrolling on |

In the menu-bar dropdown this appears as:

- Mouse: `Scrolls reversed`
- Trackpad: `Scrolls naturally`

## Accessibility Permission

ScrollSense needs Accessibility permission to read and modify scroll events.

Grant it here:

```text
System Settings -> Privacy & Security -> Accessibility
```

For the app, enable `ScrollSense.app`.

For the CLI, enable either the `scrollSense` binary or the terminal app you use
to start it.

If permission looks enabled but ScrollSense still cannot run, remove the old
entry from the Accessibility list, add it again, and relaunch ScrollSense.
macOS sometimes keeps stale entries for rebuilt or moved binaries.

## Menu-Bar App

Install:

1. Download the DMG from GitHub Releases.
2. Drag **ScrollSense** to Applications.
3. Clear quarantine for self-signed builds:

   ```bash
   xattr -dr com.apple.quarantine /Applications/ScrollSense.app
   ```

4. Launch the app.
5. Grant Accessibility permission.

Controls:

| Control | Meaning |
|---------|---------|
| Main switch | Pause or resume ScrollSense. |
| Currently | Last detected input device. |
| Mouse toggle | Whether mouse scrolling should be natural. |
| Trackpad toggle | Whether trackpad scrolling should be natural. |
| Launch at login | Register or unregister the app as a login item. |

## CLI Daemon

Install with Homebrew:

```bash
brew tap jspw/scrollsense
brew install scrollsense
```

Set preferences:

```bash
scrollSense set --mouse false --trackpad true
```

Run in the foreground:

```bash
scrollSense run --debug
```

Run in the background:

```bash
scrollSense start
scrollSense status
scrollSense stop
```

Auto-start at login:

```bash
scrollSense install
scrollSense start
```

Remove auto-start:

```bash
scrollSense uninstall
```

## Configuration File

Preferences live at:

```text
~/.scrollsense.json
```

Example:

```json
{
  "enabled" : true,
  "mouseNatural" : false,
  "trackpadNatural" : true
}
```

The menu-bar app applies changes immediately. The CLI daemon reloads the file
every two seconds.

## Troubleshooting

### Scrolling Does Not Change

Check whether both runtimes are active:

```bash
scrollSense status
```

If the daemon is running while the app is also open, stop the daemon:

```bash
scrollSense stop
```

### Accessibility Is Granted But It Still Fails

Remove ScrollSense or the terminal from Accessibility, add it again, then
relaunch. This is common after rebuilding locally or moving the binary.

### A Smooth Mouse Is Detected As Trackpad

Some mouse drivers emit continuous scroll events. ScrollSense uses macOS'
`scrollWheelEventIsContinuous` signal, so those devices may look like trackpads.
Open an issue with the mouse model, driver, macOS version, and debug output from:

```bash
scrollSense run --debug
```

### The DMG App Will Not Open

Current builds are self-signed. Clear quarantine:

```bash
xattr -dr com.apple.quarantine /Applications/ScrollSense.app
```

Then open the app again.
