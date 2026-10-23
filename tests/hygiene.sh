#!/usr/bin/env bash
# Release hygiene: no personal paths, secrets, private state, build output or excluded files in the tree.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO" || exit 1
files() { find . -path ./.git -prune -o -type f -print | grep -v '^./tests/hygiene.sh$'; }

scan() {   # scan NAME REGEX [ALLOWED-FILE-REGEX]
    local hits; hits="$(files | grep -Ev "${3:-^$}" | xargs -r grep -nIE "$2" 2>/dev/null | grep -Ev "${4:-^$}")"
    if [ -z "$hits" ]; then pass "$1"; else fail "$1"; printf '%s\n' "$hits" | head -n 10 | sed 's/^/        | /'; fi
}
scan "no absolute home paths" '/home/[a-z_][a-z0-9_-]*|/Users/[A-Za-z]'
scan "no personal names or email" 'robo4dev|jishnu|@gmail\.com' '^./(LICENSE|README\.md|SECURITY\.md|CONTRIBUTING\.md|CHANGELOG\.md|assets/wallpapers/LICENSE\.md)$'
scan "no source-checkout name (SleekShell/)" '~/SleekShell|SleekShell/'
scan "no dotfile repo references" '\bsgit\b|\.git-config'
scan "no private keys" '-----BEGIN [A-Z ]*PRIVATE KEY-----'
scan "no API keys or tokens" '(ghp|gho|ghs)_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[abp]-[0-9A-Za-z-]{10,}|sk-[A-Za-z0-9]{32,}'
scan "no hard-coded passwords" '(password|passwd|secret)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'$ ]{4,}' '^$' '"xxxx"'

excluded='^\./hypr/(monitors|monitors_custom|custom_binds|user)\.lua$|^\./quickshell/.*appearance\.json$|(^|/)(hyprlock\.conf|lock-clock\.sh|ps-symbols\.sh|workspaces\.txt|assets\.json|settings\.json|keybinds\.json|avatar[^/]*|50-sleek-shell\.conf|90-rice\.conf|sleekcalc\.so)$'
check "no personal state or excluded files" sh -c "! find . -path ./.git -prune -o -type f -print | grep -E '$excluded'"
check "no build output or caches" sh -c "! find . -path ./.git -prune -o \\( -name __pycache__ -o -name '*.pyc' -o -name '*.so' -o -name '*.o' -o -name .vscode -o -name .qmlls.ini \\) -print | grep ."
check "no symlinks" sh -c "! find . -path ./.git -prune -o -type l -print | grep ."
check "no file over 2 MiB" sh -c "! find . -path ./.git -prune -o -type f -size +2M -print | grep -v '^./assets/fonts/MaterialSymbolsRounded.ttf$' | grep ."
check "no editor backups or temp files" sh -c "! find . -path ./.git -prune -o -type f \\( -name '*~' -o -name '*.swp' -o -name '*.orig' -o -name '*.rej' -o -name '.#*' \\) -print | grep ."
check "bundled font ships its license" test -f assets/fonts/LICENSE-MaterialSymbols.txt
check "every bundled wallpaper is listed in its license file" sh -c 'for f in assets/wallpapers/*; do b="${f##*/}"; [ "$b" = LICENSE.md ] || grep -q "\`$b\`" assets/wallpapers/LICENSE.md || exit 1; done'
check "bundled images carry no metadata" sh -c '! strings assets/wallpapers/*.png | grep -qiE "c2pa|exif|xmp|gpt-image"'
check "images carry no EXIF/text metadata" sh -c "! command -v magick >/dev/null || { for f in \$(find . -path ./.git -prune -o \\( -name '*.png' -o -name '*.jpg' \\) -print); do magick identify -format '%[exif:*]%[comment]' \"\$f\" | grep -q . && { echo \$f; exit 1; }; done; true; }"

finish
