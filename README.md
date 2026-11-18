# MT Control

A native macOS app for the Rapoo MT760 / MT760L mouse. It replaces Rapoo's A HUB, which is an Intel-only Qt app that runs under Rosetta and ships Windows shortcuts.

Not affiliated with Rapoo.

## What it does

**On the mouse** (saved in the mouse, works on any computer):
- switch DPI stage
- edit the DPI value of each stage (50–4000, steps of 50) and how many stages the top button cycles through
- polling rate (125 / 250 / 500 / 1000 Hz)
- battery level, charging state, firmware version

**On the Mac** (works per app):
- remap wheel click, back and forward to macOS shortcuts, system actions (Mission Control, App windows, Show desktop, Spaces) or other mouse buttons
- gesture button: hold and move for Mission Control, App windows or switching Spaces, or click it for another action
- per-app profiles, including a DPI stage that switches automatically when that app is in front
- reverse wheel direction without touching trackpad natural scrolling, smooth scrolling, scroll speed
- low-battery notifications, battery in the menu bar, open at login

System actions use the shortcuts set in System Settings → Keyboard → Keyboard Shortcuts, so custom bindings keep working.

## Requirements

- macOS 26 or later, Apple silicon
- the MT760 2.4 GHz receiver (Bluetooth configuration isn't supported yet)

## Permissions

- **Input Monitoring**: the mouse's settings channel sits inside the receiver's keyboard interface, so macOS asks for this before the app can talk to the mouse.
- **Accessibility**: only needed once you change a button action or a scrolling option.

## Build

Needs the Xcode Command Line Tools (Xcode itself isn't required).

```sh
./scripts/bundle.sh     # builds dist/MT Control.app
./scripts/test.sh       # runs the tests
```

`bundle.sh` signs with a local identity called "MT Control Local Signing" if your keychain has one, and ad-hoc otherwise. A stable identity keeps the macOS permissions across rebuilds.

## Protocol

[docs/protocol.md](docs/protocol.md) covers the mouse's USB protocol: reverse-engineered from A HUB, then checked against a real MT760L. `~/Library/Logs/MTControl/hid.log` records every packet the app sends and receives. Device → Snapshot memory dumps the mouse's settings area for comparison.

## License

MIT
