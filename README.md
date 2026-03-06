# Print Screen App (macOS)

A tiny macOS app that listens for one global keyboard shortcut and saves a full-screen PNG with this format:

`print-screen-YYYY-MM-DD-HH-mm-ss.png`

Full setup and installation steps are in `INSTALL.md`.

Current shortcut:

`Control + Option + P`

Menu features:

- `About` (shows app credit)
- `Set Target Folder` (change where screenshots are saved)
- `Open Target Folder`

## Requirements

- macOS 13+
- Xcode Command Line Tools (`xcode-select --install`)

## Run in development

```bash
cd /opt/homebrew/var/www/print-screen
swift run
```

Keep it running in the foreground/background. Press `Control + Option + P` anytime to capture your full screen.

By default screenshots go to `~/Pictures/PrintScreenApp` (created automatically), but users can change the target folder from the app menu.

## Build release binary

```bash
cd /opt/homebrew/var/www/print-screen
swift build -c release
```

Binary path:

`./.build/release/PrintScreenApp`

## Build clickable .app bundle

```bash
cd /opt/homebrew/var/www/print-screen
./scripts/make_app_bundle.sh
open ./dist/PrintScreenApp.app
```

Bundle path:

`./dist/PrintScreenApp.app`

## Optional: launch at login

1. Build the `.app` bundle.
2. In `System Settings` -> `General` -> `Login Items`, add `./dist/PrintScreenApp.app`.

## Permissions

On first run/capture, macOS may ask for permissions. If prompted, allow:

- `Screen Recording` for Terminal (during `swift run`) or your built app/binary
- `Notifications` for PrintScreenApp (optional, for success/error popups)

## Change the shortcut

Edit these constants in `Sources/main.swift`:

- `hotKeyCode`
- `hotKeyModifiers`

Common key codes are in `Carbon.HIToolbox` (example: `kVK_ANSI_P`).
