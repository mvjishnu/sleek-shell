#!/usr/bin/env bash
# install.sh / uninstall.sh in throwaway HOMEs: dry run, install, idempotent reinstall, upgrades,
# backups and restore, refusals, missing dependencies. Runs the real installer, so it needs the
# required dependencies (or it skips the install tests).
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
INSTALL="$REPO/install.sh"
M=.local/share/sleek-shell/manifest.tsv
U=.local/share/sleek-shell/uninstall.sh

tree_sum() { (cd "$1" && find . -path ./.cache -prune -o \( -type f -o -type l \) -print0 | sort -z | xargs -0 -r sha256sum); }
no_date() { grep -v '^date' "$1"; }

check "--help" "$INSTALL" --help
check "unknown option is refused" sh -c "! '$INSTALL' --bogus"
check "unknown profile is refused" sh -c "! '$INSTALL' --profile desktop"

STUB="$TMPROOT/stub-root"; mkdir -p "$STUB"
printf '#!/bin/sh\n[ "$1" = -u ] && { echo 0; exit 0; }\nexec /usr/bin/id "$@"\n' > "$STUB/id"; chmod +x "$STUB/id"
H="$(new_home)"
check "refuses to run as root" sh -c "! PATH='$STUB:$PATH' HOME='$H' '$INSTALL' --yes >/dev/null 2>&1 && [ -z \"\$(ls -A '$H')\" ]"
check "uninstall refuses to run as root" sh -c "! PATH='$STUB:$PATH' HOME='$H' '$REPO/uninstall.sh' --yes >/dev/null 2>&1"

# ---------------------------------------------------------------- missing / old dependencies
MIN="$TMPROOT/minbin"; mkdir -p "$MIN"
for c in bash sh env id date cat sed awk grep sort cut tr head tail mkdir dirname basename readlink printf \
         uname sha256sum find mktemp rm cp mv chmod install ln stat wc ls; do
    p="$(command -v "$c")" && ln -sf "$p" "$MIN/$c"
done
H="$(new_home)"
rc=0; in_home "$H" env PATH="$MIN" "$INSTALL" --check >"$TMPROOT/min.log" 2>&1 || rc=$?
check "--check exits 3 when required deps are missing" test "$rc" = 3
check "--check names the missing compositor" grep -q 'MISSING  required     hyprland' "$TMPROOT/min.log"
check "install stops when required deps are missing (nothing written)" sh -c "! env -u XDG_CONFIG_HOME -u XDG_DATA_HOME HOME='$H' PATH='$MIN' '$INSTALL' --yes >/dev/null 2>&1 && [ -z \"\$(ls -A '$H')\" ]"
OLD="$TMPROOT/oldbin"; mkdir -p "$OLD"
printf '#!/bin/sh\necho "Hyprland 0.41.2 built from branch  at commit abc"\n' > "$OLD/Hyprland"; chmod +x "$OLD/Hyprland"
rc=0; in_home "$H" env PATH="$OLD:$PATH" "$INSTALL" --check >"$TMPROOT/old.log" 2>&1 || rc=$?
check "Hyprland older than 0.55 fails --check" sh -c "[ $rc = 3 ] && grep -q 'Hyprland 0.41.2 is too old' '$TMPROOT/old.log'"

if ! "$INSTALL" --check >/dev/null 2>&1; then
    skip "install / uninstall round trips" "required dependencies missing on this machine (see ./install.sh --check)"
    finish; exit $?
fi

# ---------------------------------------------------------------- fresh install
H="$(new_home)"
in_home "$H" "$INSTALL" --dry-run >"$TMPROOT/dry.log" 2>&1
check "dry run changes nothing" sh -c "[ -z \"\$(ls -A '$H')\" ] && grep -q 'nothing was changed' '$TMPROOT/dry.log'"
check "without a terminal it needs --yes" sh -c "! env -u XDG_CONFIG_HOME HOME='$H' SLEEK_SYS_ROOT='$TMPROOT/sys' '$INSTALL' </dev/null >/dev/null 2>&1 && [ -z \"\$(ls -A '$H')\" ]"
check "install (full profile)" in_home "$H" "$INSTALL" --yes
check "shell, hypr, calc, fonts, docs installed" sh -c "cd '$H' && test -f .config/quickshell/shell.qml -a -f .config/hypr/hyprland.lua -a -x .local/bin/sleek-calc \
    -a -f .local/share/fonts/sleek-shell/MaterialSymbolsRounded.ttf -a -x $U -a -f .local/share/sleek-shell/greeter/install.sh -a -f $M"
check "bundled wallpaper installed" cmp -s "$REPO/assets/wallpapers/astronaut-planet.png" "$H/Pictures/Wallpapers/sleek-shell-astronaut.png"
check "desktop entry points at the installed calculator" grep -qx "Exec=$H/.local/bin/sleek-calc" "$H/.local/share/applications/sleek-calc.desktop"
check "kitty and rofi defaults installed and themed" sh -c "grep -q '\"kitty\"' '$H/.config/sleek-shell/app-themes.json' && grep -q '\"rofi\"' '$H/.config/sleek-shell/app-themes.json' && test -f '$H/.config/kitty/kitty.conf'"
check "manifest paths are all inside HOME" sh -c "! awk -F'\t' '\$1==\"file\"||\$1==\"gen\"{print \$3}' '$H/$M' | grep -v '^$H/'"
check "every manifest file exists with its hash" sh -c "awk -F'\t' '\$1==\"file\"{print \$2\"  \"\$3}' '$H/$M' | sha256sum -c --quiet"
check "the installed hypr config verifies" sh -c "env -u XDG_CONFIG_HOME HOME='$H' XDG_RUNTIME_DIR='$H' Hyprland --verify-config -c '$H/.config/hypr/hyprland.lua' 2>&1 | grep -q 'config ok'"

cp "$H/$M" "$TMPROOT/m1"; sleep 1
check "reinstall" in_home "$H" "$INSTALL" --yes
check "reinstall is idempotent (same manifest, no backups)" sh -c "diff <(grep -v ^date '$TMPROOT/m1') <(grep -v ^date '$H/$M') && [ ! -e '$H/.local/share/sleek-shell-backups' ]"

echo '-- mine' >> "$H/.config/hypr/modules/keybinds.lua"
echo 'return {}' > "$H/.config/hypr/monitors.lua"; echo '-- mine' > "$H/.config/hypr/user.lua"
echo '{"clock24h":true}' > "$H/.config/sleek-shell/settings.json"
sleep 1; in_home "$H" "$INSTALL" --yes >"$TMPROOT/up.log" 2>&1
check "upgrade saves an edited managed file under edited/" sh -c "ls '$H'/.local/share/sleek-shell-backups/*/edited/.config/hypr/modules/keybinds.lua && ! grep -q -- '-- mine' '$H/.config/hypr/modules/keybinds.lua'"
check "upgrade keeps monitors.lua, user.lua, settings.json" sh -c "grep -q 'return {}' '$H/.config/hypr/monitors.lua' && grep -q mine '$H/.config/hypr/user.lua' && grep -q clock24h '$H/.config/sleek-shell/settings.json'"

echo 'changed' >> "$H/.config/quickshell/shell.qml"
mkdir -p "$TMPROOT/sys/etc/greetd/sleek-shell"
refuses_greeter() { ! SYS="$TMPROOT/sys" in_home "$H" "$H/$U" --yes >"$TMPROOT/g.log" 2>&1 && grep -q 'greeter is installed' "$TMPROOT/g.log" && test -f "$H/$M"; }
check "uninstall refuses while the greeter is installed" refuses_greeter
check "uninstall --keep-greeter --dry-run is accepted" in_home "$H" "$H/$U" --keep-greeter --dry-run
rmdir "$TMPROOT/sys/etc/greetd/sleek-shell" "$TMPROOT/sys/etc/greetd" "$TMPROOT/sys/etc"
before="$(tree_sum "$H")"
in_home "$H" "$H/$U" --dry-run >/dev/null 2>&1
check "uninstall --dry-run changes nothing" test "$before" = "$(tree_sum "$H")"
check "uninstall without a terminal needs --yes" sh -c "! env -u XDG_CONFIG_HOME -u XDG_DATA_HOME HOME='$H' SLEEK_SYS_ROOT='$TMPROOT/sys' '$H/$U' </dev/null >/dev/null 2>&1"
in_home "$H" "$H/$U" --yes >"$TMPROOT/un.log" 2>&1
check "uninstall" grep -q 'Packages were not removed' "$TMPROOT/un.log"
check "uninstall keeps files you changed and lists them" sh -c "grep -q changed '$H/.config/quickshell/shell.qml' && grep -q 'quickshell/shell.qml' '$TMPROOT/un.log'"
check "uninstall leaves only your files" sh -c "cd '$H' && [ \"\$(find . -path ./.cache -prune -o -path ./.local/share/sleek-shell-backups -prune -o -path ./.local/state -prune -o -type f -print | sort | tr '\n' ' ')\" = './.config/hypr/monitors.lua ./.config/hypr/user.lua ./.config/quickshell/shell.qml ./.config/sleek-shell/settings.json ' ]"
check "no manifest or binaries left" sh -c "cd '$H' && [ ! -e $M ] && [ ! -e .local/bin/sleek-calc ] && [ ! -e .local/lib/rofi/sleekcalc.so ]"

# ---------------------------------------------------------------- existing configs
H="$(new_home)"; mkdir -p "$H"/.config/{quickshell,hypr,kitty,rofi}
echo 'import QtQuick; Item {}' > "$H/.config/quickshell/shell.qml"
echo 'monitor = ,preferred,auto,1' > "$H/.config/hypr/hyprland.conf"
echo 'font_size 14' > "$H/.config/kitty/kitty.conf"
echo 'configuration {}' > "$H/.config/rofi/config.rasi"
mkdir -p "$H/Pictures/Wallpapers"; echo mine > "$H/Pictures/Wallpapers/sleek-shell-astronaut.png"
orig="$(tree_sum "$H")"
in_home "$H" "$INSTALL" --yes >"$TMPROOT/e1.log" 2>&1
check "existing quickshell config is backed up and replaced" sh -c "grep -q '^backup	$H/.config/quickshell	' '$H/$M' && test -f '$H/.config/quickshell/shell.qml' && ! grep -q 'Item {}' '$H/.config/quickshell/shell.qml'"
check "a wallpaper with the same name is kept" grep -qx mine "$H/Pictures/Wallpapers/sleek-shell-astronaut.png"
check "existing hypr config is kept (no --replace-hypr)" sh -c "test -f '$H/.config/hypr/hyprland.conf' -a ! -e '$H/.config/hypr/hyprland.lua' && grep -q 'docs/CONFIG.md' '$TMPROOT/e1.log'"
check "existing kitty and rofi configs are kept, not themed" sh -c "grep -q 'font_size 14' '$H/.config/kitty/kitty.conf' && grep -q 'configuration {}' '$H/.config/rofi/config.rasi' && grep -q '\"apps\": {}' '$H/.config/sleek-shell/app-themes.json'"
sleep 1
check "--replace-hypr backs up and replaces it" sh -c "env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u HYPRLAND_INSTANCE_SIGNATURE HOME='$H' SLEEK_SYS_ROOT='$TMPROOT/sys' '$INSTALL' --yes --replace-hypr >/dev/null 2>&1 && test -f '$H/.config/hypr/hyprland.lua' && grep -q '^backup	$H/.config/hypr	' '$H/$M'"
check "uninstall --purge" in_home "$H" "$H/$U" --yes --purge
check "your original configs are restored exactly" test "$orig" = "$(tree_sum "$H" | grep -v sleek-shell-backups)"
check "purge removes settings and fonts" sh -c "[ ! -e '$H/.config/sleek-shell' ] && [ ! -e '$H/.local/share/fonts/sleek-shell' ]"

# ---------------------------------------------------------------- shell profile
H="$(new_home)"
check "--profile shell" in_home "$H" "$INSTALL" --yes --profile shell
check "shell profile leaves ~/.config/hypr alone" sh -c "test -f '$H/.config/quickshell/shell.qml' -a ! -e '$H/.config/hypr' && grep -qx 'profile	shell' '$H/$M'"

# ---------------------------------------------------------------- upgrade drops files no longer shipped
R2="$TMPROOT/repo2"; mkdir -p "$R2"
(cd "$REPO" && tar --exclude=./.git --exclude='*/__pycache__' --exclude=./screenshots -cf - .) | (cd "$R2" && tar -xf -)
H="$(new_home)"
in_home "$H" "$R2/install.sh" --yes >/dev/null 2>&1
rm "$R2/quickshell/scripts/quick-check.sh" "$R2/quickshell/scripts/clipboard-history.sh"
echo '# mine' >> "$H/.config/quickshell/scripts/clipboard-history.sh"
sleep 1; in_home "$H" "$R2/install.sh" --yes >"$TMPROOT/stale.log" 2>&1
check "upgrade removes an unmodified file that is no longer shipped" test ! -e "$H/.config/quickshell/scripts/quick-check.sh"
check "upgrade keeps a modified file that is no longer shipped" grep -q '# mine' "$H/.config/quickshell/scripts/clipboard-history.sh"

finish
