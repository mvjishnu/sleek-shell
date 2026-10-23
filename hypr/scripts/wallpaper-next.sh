#!/usr/bin/env bash
# Cycle to the next wallpaper in $WALLPAPER_DIR using the running awww daemon.
#   wallpaper-next.sh          -> next wallpaper
#   wallpaper-next.sh prev     -> previous wallpaper
#   wallpaper-next.sh set PATH -> use a specific file
#   wallpaper-next.sh random   -> jump to a random one
#
# The directory is scanned every time, so wallpapers you add or download are picked
# up automatically with no config edits. Handles a missing/empty directory by
# telling the user instead of failing silently.
set -u

DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/awww-rice/last-wallpaper"
TRANSITION="${AWWW_TRANSITION:-wave}"
TRANSITION_DURATION="${AWWW_TRANSITION_DURATION:-0.6}"
TRANSITION_FPS="${AWWW_TRANSITION_FPS:-60}"
TRANSITION_STEP="${AWWW_TRANSITION_STEP:-90}"

notify() { command -v notify-send >/dev/null && notify-send -a "Wallpaper" -t 3000 "$@"; }

die() { notify "$1" "${2:-}"; echo "wallpaper: $1 ${2:-}" >&2; exit 1; }

command -v awww >/dev/null || die "awww is not installed" "Install the awww package (see docs/DISTROS.md)"

mode="${1:-next}"

if [ ! -d "$DIR" ]; then
    die "Wallpaper folder not found" "$DIR"
fi

# Only real images. awww supports png/jpg/jpeg/webp/gif/bmp.
mapfile -d '' files < <(
    find "$DIR" -maxdepth 1 -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
        -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \) -print0 \
        | sort -z
)

if [ "${#files[@]}" -eq 0 ]; then
    die "No wallpapers found" "Add images to $DIR"
fi

current=""
[ -f "$STATE" ] && current="$(cat "$STATE" 2>/dev/null)"

pick=""
case "$mode" in
    set)
        pick="${2:-}"
        [ -f "$pick" ] || die "Wallpaper not found" "$pick"
        ;;
    prev)
        for i in "${!files[@]}"; do
            if [ "${files[$i]}" = "$current" ]; then
                idx=$(( i - 1 )); [ "$idx" -lt 0 ] && idx=$(( ${#files[@]} - 1 ))
                pick="${files[$idx]}"; break
            fi
        done
        [ -n "$pick" ] || pick="${files[$((${#files[@]} - 1))]}"
        ;;
    random)
        pick="${files[$((RANDOM % ${#files[@]}))]}"
        ;;
    *)
        for i in "${!files[@]}"; do
            if [ "${files[$i]}" = "$current" ]; then
                pick="${files[$(( (i + 1) % ${#files[@]} ))]}"; break
            fi
        done
        [ -n "$pick" ] || pick="${files[0]}"
        ;;
esac

# Make sure the daemon is alive (idempotent: awww-daemon exits if one is running).
if ! awww query >/dev/null 2>&1; then
    if command -v awww-daemon >/dev/null; then
        awww-daemon >/dev/null 2>&1 &
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            awww query >/dev/null 2>&1 && break
            sleep 0.2
        done
    fi
fi
awww query >/dev/null 2>&1 || die "Wallpaper daemon not running" "awww-daemon"

awww img "$pick" \
    --transition-type "$TRANSITION" \
    --transition-duration "$TRANSITION_DURATION" \
    --transition-fps "$TRANSITION_FPS" \
    --transition-step "$TRANSITION_STEP" \
    >/dev/null 2>&1 || die "Could not apply wallpaper" "$(basename "$pick")"

mkdir -p "$(dirname "$STATE")" 2>/dev/null
printf '%s' "$pick" > "$STATE" 2>/dev/null

notify "Wallpaper: $(basename "$pick")" "$(basename "$DIR")"
