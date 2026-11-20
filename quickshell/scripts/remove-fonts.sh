#!/bin/sh
# Move font files out of the system font paths (used with pkexec by desktop-prefs.py).
# Usage: remove-fonts.sh BACKUP_DIR FILE...
# Runs as root, so it only accepts a backup dir under /var/backups/sleek-shell/ and font files
# under the system font directories; anything else is refused.
set -eu
PATH=/usr/bin:/bin
[ "$#" -ge 2 ] || { echo "usage: remove-fonts.sh BACKUP_DIR FILE..." >&2; exit 2; }
backup="$1"
shift
case "$backup" in
    /var/backups/sleek-shell/*) ;;
    *) echo "refusing backup dir outside /var/backups/sleek-shell: $backup" >&2; exit 2 ;;
esac
case "$backup" in *..*) echo "refusing backup dir with '..': $backup" >&2; exit 2 ;; esac
for f in "$@"; do
    real=$(realpath -e -- "$f" 2>/dev/null) || continue
    case "$real" in
        /usr/share/fonts/*|/usr/local/share/fonts/*) ;;
        *) echo "refusing non-system font path: $f" >&2; exit 2 ;;
    esac
    case "$real" in
        *.ttf|*.otf|*.ttc|*.otc|*.pfb|*.pfa|*.woff|*.woff2|*.TTF|*.OTF) ;;
        *) echo "refusing non-font file: $f" >&2; exit 2 ;;
    esac
done
mkdir -p "$backup"
for f in "$@"; do
    real=$(realpath -e -- "$f" 2>/dev/null) || continue
    [ -f "$real" ] || continue
    base=$(basename "$real")
    dest="$backup/$base"
    if [ -e "$dest" ]; then
        dest="$backup/$(date +%s)-$base"
    fi
    mv -f -- "$real" "$dest"
done
if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f >/dev/null 2>&1 || true
fi
