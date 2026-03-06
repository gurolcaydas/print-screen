#!/usr/bin/env python3
"""Global hotkey screenshot tool for macOS.

Shortcut: Ctrl+Option+P
Output: ~/Desktop/print-screen-YYYY-MM-DD-HH-mm-ss.png
"""

from __future__ import annotations

import datetime as dt
import subprocess
from pathlib import Path

from pynput import keyboard

HOTKEY = "<ctrl>+<alt>+p"


def build_output_path() -> Path:
    timestamp = dt.datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
    filename = f"print-screen-{timestamp}.png"
    return Path.home() / "Desktop" / filename


def capture_screen() -> None:
    output_path = build_output_path()
    try:
        subprocess.run(
            ["/usr/sbin/screencapture", "-x", str(output_path)],
            check=True,
        )
        print(f"Saved: {output_path}")
    except subprocess.CalledProcessError as exc:
        print(f"Screenshot failed with exit code {exc.returncode}")


def main() -> None:
    print("Print Screen Python app is running.")
    print("Press Ctrl+Option+P to capture the full screen.")
    print("Press Ctrl+C in this terminal to quit.")

    with keyboard.GlobalHotKeys({HOTKEY: capture_screen}) as listener:
        listener.join()


if __name__ == "__main__":
    main()
