# Installation Guide

This guide shows how to install and run **PrintScreenApp** on macOS.

## What This App Does

- Runs as a small menu bar utility.
- Captures full screen with one shortcut: `Control + Option + P`.
- Saves file to Desktop as: `print-screen-YYYY-MM-DD-HH-mm-ss.png`.

## Requirements

- macOS 13 or newer
- Xcode Command Line Tools

Install command line tools if needed:

```bash
xcode-select --install
```

## Option 1: Run Directly (Development)

```bash
git clone <YOUR_GITHUB_REPO_URL>
cd print-screen
swift run
```

Keep the app running. Use `Control + Option + P` to capture.

## Option 2: Build Clickable .app Bundle (Recommended)

```bash
git clone <YOUR_GITHUB_REPO_URL>
cd print-screen
./scripts/make_app_bundle.sh
open ./dist/PrintScreenApp.app
```

Bundle output:

`dist/PrintScreenApp.app`

## Optional: Install to Applications

```bash
cp -R ./dist/PrintScreenApp.app /Applications/
open /Applications/PrintScreenApp.app
```

## Start Automatically at Login

1. Open `System Settings`.
2. Go to `General` -> `Login Items`.
3. Add `/Applications/PrintScreenApp.app` (or your `dist/PrintScreenApp.app`).

## Permissions (First Run)

macOS may prompt for:

- `Screen Recording`: required to capture the screen.
- `Notifications`: optional, used for success/error popups.

If screenshots fail:

1. Open `System Settings` -> `Privacy & Security` -> `Screen Recording`.
2. Enable access for Terminal (if running from `swift run`) or `PrintScreenApp` (if using `.app`).
3. Restart the app.

## Uninstall

1. Quit the app from menu bar -> `Quit`.
2. Remove the app bundle:

```bash
rm -rf /Applications/PrintScreenApp.app
```

3. Optional: remove local clone folder.
