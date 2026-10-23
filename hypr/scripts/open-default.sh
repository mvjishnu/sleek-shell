#!/usr/bin/env bash
# Open the user's default browser or file manager (Hyprland binds SUPER+B / SUPER+E).
#   open-default.sh browser | files
set -u

launch_desktop() {
    local id="${1%.desktop}"
    [ -n "$id" ] || return 1
    if command -v gtk-launch >/dev/null 2>&1; then
        gtk-launch "$id" >/dev/null 2>&1 & disown
        return 0
    fi
    return 1
}

case "${1:-}" in
    browser)
        d="$(xdg-settings get default-web-browser 2>/dev/null || true)"
        [ -n "$d" ] || d="$(xdg-mime query default x-scheme-handler/https 2>/dev/null || true)"
        launch_desktop "$d" && exit 0
        for b in firefox chromium google-chrome-stable brave zen-browser librewolf epiphany; do
            command -v "$b" >/dev/null 2>&1 && { "$b" >/dev/null 2>&1 & disown; exit 0; }
        done
        ;;
    files)
        d="$(xdg-mime query default inode/directory 2>/dev/null || true)"
        launch_desktop "$d" && exit 0
        command -v xdg-open >/dev/null 2>&1 && { xdg-open "$HOME" >/dev/null 2>&1 & disown; exit 0; }
        ;;
    *)
        echo "usage: $0 browser|files" >&2
        exit 2
        ;;
esac

command -v notify-send >/dev/null 2>&1 && notify-send -a "Sleek Shell" "No default ${1} found" "Set one with xdg-settings / xdg-mime, or export SLEEK_BROWSER / SLEEK_FILE_MANAGER."
exit 1
