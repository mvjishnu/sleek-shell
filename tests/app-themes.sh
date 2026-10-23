#!/usr/bin/env bash
# Per-app theming: runs apply-theme.sh in a throwaway HOME and checks inherit / custom / off / legacy exports.
set -eu
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AT="$REPO/quickshell/scripts/apply-theme.sh"
S=$(mktemp -d /tmp/sleek-apptheme.XXXXXX); trap 'rm -rf "$S"' EXIT
mkdir -p "$S/.config/kitty" "$S/.config/rofi/themes" "$S/.config/gtk-3.0" "$S/.config/gtk-4.0"
printf 'font_size 11\n' > "$S/.config/kitty/kitty.conf"
cp "$REPO/defaults/rofi/themes/rice.rasi" "$S/.config/rofi/themes/"
touch "$S/.config/gtk-3.0/gtk.css" "$S/.config/gtk-4.0/gtk.css"
base='{"tintR":29,"tintG":29,"tintB":35,"accent":"#b69aff","text":"#f2f2f7","muted":"#a8a8b4","dim":"#6c6c78","glass":0.6,"mode":"dark","styleMode":"glass"}'
run() { HOME="$S" XDG_CONFIG_HOME="$S/.config" bash "$AT" "$1" >/dev/null 2>&1; }

echo "$base" > "$S/legacy.json"; run "$S/legacy.json"
grep -q '^cursor  *#b69aff' "$S/.config/kitty/theme.conf"
grep -q '@define-color accent_color #b69aff' "$S/.config/gtk-3.0/gtk.css"

echo "$base" | jq '.apps={kitty:{on:false},rofi:{on:true},gtk:{on:true,tintR:78,tintG:34,tintB:58,accent:"#ff00aa",text:"#fff1f6",muted:"#d6a6bb",dim:"#aa7788"},qt:{on:false},micro:{on:false}}' > "$S/new.json"
rm -f "$S/.config/kdeglobals" "$S/.config/micro/colorschemes/rice.micro"
run "$S/new.json"
grep -q 'theming is off for kitty' "$S/.config/kitty/theme.conf"
! grep -q '^cursor' "$S/.config/kitty/theme.conf"
grep -q '@define-color accent_color #ff00aa' "$S/.config/gtk-3.0/gtk.css"
grep -q '@define-color accent_color #ff00aa' "$S/.config/gtk-4.0/gtk.css"
grep -q 'accent: *#b69aff' "$S/.config/rofi/themes/rice.rasi"
[ ! -e "$S/.config/micro/colorschemes/rice.micro" ]
if command -v kwriteconfig6 >/dev/null; then [ ! -e "$S/.config/kdeglobals" ]; fi
echo ok
