#!/usr/bin/env bash
set -u
echo "Quickshell:"
command -v quickshell || command -v qs || true
echo
echo "Required commands:"
for c in wl-paste cliphist wl-copy nmcli bluetoothctl wpctl brightnessctl playerctl powerprofilesctl; do
    if command -v "$c" >/dev/null 2>&1; then printf '  OK   %s\n' "$c"; else printf '  MISS %s\n' "$c"; fi
done
echo
echo "Backlight devices:"
ls /sys/class/backlight 2>/dev/null || true
echo
echo "Hyprland monitor names:"
hyprctl monitors 2>/dev/null | grep -E 'Monitor |description:' || true
