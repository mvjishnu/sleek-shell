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
# The Quickshell theme (palette, accent, glass), kitty, rofi and micro keep
# their own colours: those are the "theme", not the light/dark mode.
# The KDE/Qt app colours are written by apply-theme.sh, which reads the mode
# from the exported theme file.
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
    [ -f "$ini" ] || continue
    if grep -q '^gtk-application-prefer-dark-theme=' "$ini" 2>/dev/null; then
        sed -i "s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=$DARK/" "$ini"
    else
        printf '\ngtk-application-prefer-dark-theme=%s\n' "$DARK" >> "$ini"
    fi
done

# ---------------------------------------------------------------------------
# libadwaita + xdg-desktop-portal-gtk: the modern "system is dark" flag
# ---------------------------------------------------------------------------
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme "$GSCHEME" 2>/dev/null || true
fi

exit 0
