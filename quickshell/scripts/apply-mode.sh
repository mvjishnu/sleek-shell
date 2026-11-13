#!/usr/bin/env bash
# Switches the whole system between dark and light mode.
#
# Usage: apply-mode.sh dark|light
#
# This only moves the light/dark axis of the desktop:
#   * GTK 3 / GTK 4 apps   -> gtk-application-prefer-dark-theme
#                             (also picked up by Electron/Chromium and Firefox/Zen,
#                              they ask GTK whether the system is dark)
#   * libadwaita apps,
#     xdg-desktop-portal-gtk -> org.gnome.desktop.interface color-scheme
#
# Palette-aware app colors are written by apply-theme.sh from the exported
# theme file. This script updates GTK/libadwaita's native light/dark preference.
#
# Already running apps keep their old look until they are restarted.
set -u

MODE="${1:-dark}"
case "$MODE" in
    dark)  DARK=1; GSCHEME="prefer-dark"  ;;
    light) DARK=0; GSCHEME="prefer-light" ;;
    *) exit 0 ;;
esac

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

# ---------------------------------------------------------------------------
# GTK 3 + GTK 4: the dark preference every GTK app reads at startup
# ---------------------------------------------------------------------------
for v in 3.0 4.0; do
    ini="$CFG/gtk-$v/settings.ini"
    mkdir -p "$(dirname "$ini")" 2>/dev/null
    python3 - "$ini" gtk-application-prefer-dark-theme "$DARK" <<'PY'
import os, re, sys
path, key, value = sys.argv[1:]
try: lines = open(path).read().splitlines()
except FileNotFoundError: lines = []
out, in_settings, found, section_seen = [], False, False, False
for line in lines:
    if re.match(r'^\s*\[.*\]\s*$', line):
        if in_settings and not found:
            out.append(f'{key}={value}'); found = True
        in_settings = line.strip().lower() == '[settings]'
        section_seen |= in_settings
        out.append(line)
    elif in_settings and re.match(r'^\s*' + re.escape(key) + r'\s*=', line):
        if not found: out.append(f'{key}={value}'); found = True
    else: out.append(line)
if in_settings and not found: out.append(f'{key}={value}'); found = True
if not section_seen: out.extend(([''] if out and out[-1] else []) + ['[Settings]', f'{key}={value}'])
tmp = path + '.tmp'
with open(tmp, 'w') as f: f.write('\n'.join(out) + '\n')
os.replace(tmp, path)
PY
done

# ---------------------------------------------------------------------------
# libadwaita + xdg-desktop-portal-gtk: the modern "system is dark" flag
# ---------------------------------------------------------------------------
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme "$GSCHEME" 2>/dev/null || true
fi

exit 0
