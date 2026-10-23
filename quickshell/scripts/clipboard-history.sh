#!/usr/bin/env bash
set -euo pipefail
command -v cliphist >/dev/null || { notify-send "Clipboard history" "Install cliphist first."; exit 1; }
command -v wl-copy >/dev/null || { notify-send "Clipboard history" "Install wl-clipboard first."; exit 1; }
# This script is a fallback launcher; the primary panel is rendered by Quickshell.
if command -v rofi >/dev/null; then
    cliphist list | rofi -dmenu -i -p "Clipboard" | cliphist decode | wl-copy
else
    notify-send "Clipboard history" "Rofi is not installed. Open the Quickshell clipboard panel instead."
fi
