#!/usr/bin/env bash
# Sleek Shell installer (per-user; never touches /etc; sudo only with --install-deps, after you confirm).
#
#   ./install.sh --check                 distro, init system, display manager, missing dependencies
#   ./install.sh --install-deps          also install missing packages from your distro's repositories
#   ./install.sh --dry-run               show exactly what would be installed / backed up
#   ./install.sh                         install the full profile (asks before changing anything)
#   ./install.sh --profile shell         Quickshell shell only, keep your Hyprland config
#   ./install.sh --replace-hypr          allow replacing an existing non-Sleek ~/.config/hypr (it is backed up)
#
# Options: --profile full|shell, --replace-hypr, --install-deps, --with-optional, --dry-run, --check,
#          --yes, --ignore-deps, --help. --install-deps always asks on the terminal (--yes does not answer
#          it) and never installs a display manager. Replaced files go to ~/.local/share/sleek-shell-backups/
# and ~/.local/share/sleek-shell/uninstall.sh puts them back. The login greeter is separate: docs/GREETER.md.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"
# shellcheck source=lib/distro.sh
. "$HERE/lib/distro.sh"
# shellcheck source=lib/deps.sh
. "$HERE/lib/deps.sh"

VERSION="$(cat "$HERE/VERSION" 2>/dev/null || echo 0.0.0)"
PROFILE=full
REPLACE_HYPR=0
CHECK_ONLY=0
YES=0
IGNORE_DEPS=0
INSTALL_DEPS=0
WITH_OPTIONAL=0

usage() { sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case "$1" in
        --profile) [ $# -ge 2 ] || die "--profile needs a value"; PROFILE="$2"; shift ;;
        --profile=*) PROFILE="${1#*=}" ;;
        --replace-hypr) REPLACE_HYPR=1 ;;
        --dry-run|-n) DRY=1 ;;
        --check) CHECK_ONLY=1 ;;
        --yes|-y) YES=1 ;;
        --ignore-deps) IGNORE_DEPS=1 ;;
        --install-deps) INSTALL_DEPS=1 ;;
        --with-optional) WITH_OPTIONAL=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1 (see --help)" ;;
    esac
    shift
done
case "$PROFILE" in full|shell) ;; *) die "unknown profile '$PROFILE' (full or shell)" ;; esac

[ "$(id -u)" != 0 ] || die "run as your own user, not root: Sleek Shell installs into your home directory"
[ -n "${HOME:-}" ] && [ -d "$HOME" ] || die "HOME is not set"

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DATA="$DATA_HOME/sleek-shell"
BIN="$HOME/.local/bin"
MANIFEST="$DATA/manifest.tsv"
BACKUP_DIR="$DATA_HOME/sleek-shell-backups/$(date +%Y%m%d-%H%M%S)"

# ------------------------------------------------------------------------------------- report
detect_distro
head1 "Sleek Shell $VERSION"
say "  distro        $DISTRO_NAME (family: $DISTRO_FAMILY, $DISTRO_SUPPORT)"
say "  init          $(init_system)"
say "  display mgr   $(display_manager)$( [ "$(greetd_uses_sleek)" = yes ] && echo ' (Sleek greeter configured)')"
say "  session       ${XDG_CURRENT_DESKTOP:-none}${WAYLAND_DISPLAY:+ (Wayland)}"
say "  profile       $PROFILE$( [ "$DRY" = 1 ] && echo ', dry run')"

[ "$DISTRO_SUPPORT" = supported ] || warn "$DISTRO_NAME is $DISTRO_SUPPORT: see docs/DISTROS.md"
[ "$(init_system)" = systemd ] || warn "no systemd: the power menu uses systemctl (see docs/TROUBLESHOOTING.md)"

head1 "Dependencies"
deps_ok=1
check_deps "$DISTRO_FAMILY" || deps_ok=0
for p in "${DEP_VERSION_PROBLEMS[@]}"; do warn "$p"; done
report_missing() {
    local hint
    hint="$(install_hint "$DISTRO_FAMILY")"
    [ -z "$hint" ] || say "  missing packages from the $DISTRO_FAMILY repositories (./install.sh --install-deps runs this after asking):
    $hint"
    hint="$(install_hint "$DISTRO_FAMILY" optional)"
    [ -z "$hint" ] || say "  optional extras (--install-deps --with-optional):
    $hint"
    [ "$((${#DEP_MANUAL[@]} + ${#DEP_UNPACKAGED[@]}))" = 0 ] || { say "  not installable from the default repositories:"; deps_notes "$DISTRO_FAMILY"; }
}
report_missing

if [ "$INSTALL_DEPS" = 1 ]; then
    head1 "Installing dependencies"
    if install_deps "$DISTRO_FAMILY" "$WITH_OPTIONAL" && [ "$DRY" = 0 ]; then
        head1 "Dependencies after installing"
        deps_ok=1
        check_deps "$DISTRO_FAMILY" || deps_ok=0
        for p in "${DEP_VERSION_PROBLEMS[@]}"; do warn "$p"; done
        report_missing
    fi
fi
service_hints

if [ "$CHECK_ONLY" = 1 ]; then
    [ -f "$MANIFEST" ] && say "
  installed: $(awk -F'\t' '$1=="version"{print $2}' "$MANIFEST") ($MANIFEST)"
    [ "$deps_ok" = 1 ] && exit 0 || exit 3
fi

if [ "$deps_ok" = 0 ]; then
    if [ "$IGNORE_DEPS" = 1 ] || [ "$DRY" = 1 ]; then warn "required dependencies are missing; continuing ($( [ "$DRY" = 1 ] && echo dry run || echo --ignore-deps))"
    else die "required dependencies are missing (install them, or pass --ignore-deps to install the files anyway)"; fi
fi

# ---------------------------------------------------------------------------------------- plan
load_old_manifest "$MANIFEST"
[ -f "$MANIFEST" ] && say "
  upgrading the install recorded in $MANIFEST"

HYPR_ACTION=skip
if [ "$PROFILE" = full ]; then
    if [ ! -e "$CFG/hypr" ]; then HYPR_ACTION=install
    elif owned_under "$CFG/hypr"; then HYPR_ACTION=upgrade
    elif [ "$REPLACE_HYPR" = 1 ]; then HYPR_ACTION=replace
    else HYPR_ACTION=keep; fi
fi
QS_ACTION=install
if [ -e "$CFG/quickshell" ]; then
    if owned_under "$CFG/quickshell"; then QS_ACTION=upgrade; else QS_ACTION=replace; fi
fi

head1 "Plan"
say "  ~/.config/quickshell        $QS_ACTION$( [ "$QS_ACTION" = replace ] && echo ' (your current one is backed up first)')"
case "$HYPR_ACTION" in
    install) say "  ~/.config/hypr              install" ;;
    upgrade) say "  ~/.config/hypr              upgrade (monitors.lua, custom_binds.lua, user.lua are kept)" ;;
    replace) say "  ~/.config/hypr              replace (your current one is backed up first)" ;;
    keep)    say "  ~/.config/hypr              keep yours (pass --replace-hypr to use Sleek Shell's; see docs/CONFIG.md)" ;;
    skip)    say "  ~/.config/hypr              not touched (profile shell)" ;;
esac
say "  rofi / kitty defaults       only where you have no config yet"
say "  calculator                  ~/.local/bin/sleek-calc + desktop entry"
say "  icon font                   ~/.local/share/fonts/sleek-shell/"
say "  wallpaper                   ~/Pictures/Wallpapers/sleek-shell-astronaut.png (if absent)"
say "  docs, greeter, uninstaller  ${DATA/#$HOME/\~}/"
say "  backups                     ${BACKUP_DIR/#$HOME/\~}/ (only if something is replaced)"

if [ "$DRY" = 0 ] && [ "$YES" = 0 ]; then
    if [ -t 0 ]; then
        printf '\nContinue? [y/N] '
        read -r reply
        case "$reply" in y|Y|yes|YES) ;; *) say "Nothing changed."; exit 0 ;; esac
    else
        die "not a terminal: re-run with --yes to confirm (or --dry-run to preview)"
    fi
fi

# --------------------------------------------------------------------------------------- install
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sleek-shell-install.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

head1 "Quickshell"
[ "$QS_ACTION" = replace ] && backup_away "$CFG/quickshell"
place_tree "$HERE/quickshell" "$CFG/quickshell"
remove_stale "$CFG/quickshell"
ok "shell files ($COUNT_FILES)"

if [ "$HYPR_ACTION" != skip ]; then
    head1 "Hyprland"
    if [ "$HYPR_ACTION" = keep ]; then
        say "  kept your ~/.config/hypr. Sleek Shell's config is in ${DATA/#$HOME/\~}/hypr for reference."
        say "  The minimum your config needs is in docs/CONFIG.md (autostart quickshell, awww-daemon, cliphist)."
    else
        [ "$HYPR_ACTION" = replace ] && backup_away "$CFG/hypr"
        n0=$COUNT_FILES
        place_tree "$HERE/hypr" "$CFG/hypr"
        remove_stale "$CFG/hypr"
        ok "Hyprland config ($((COUNT_FILES - n0)) files)"
        if command -v Hyprland >/dev/null 2>&1 && [ "$DRY" = 0 ]; then
            if Hyprland --verify-config -c "$CFG/hypr/hyprland.lua" >"$TMP/verify.log" 2>&1; then ok "Hyprland --verify-config: config ok"
            else warn "Hyprland --verify-config reported problems:"; tail -n 5 "$TMP/verify.log" | sed 's/^/        /' >&2; fi
        fi
    fi
fi

head1 "Defaults"
THEMED=()
installed_default() { [ -n "${NEW_FILES[$1]+x}" ]; }
place "$HERE/defaults/rofi/config.rasi" "$CFG/rofi/config.rasi" 644 ifabsent
place "$HERE/defaults/rofi/themes/rice.rasi" "$CFG/rofi/themes/rice.rasi" 644 ifabsent
installed_default "$CFG/rofi/config.rasi" && installed_default "$CFG/rofi/themes/rice.rasi" && THEMED+=(rofi)
place "$HERE/defaults/kitty/kitty.conf" "$CFG/kitty/kitty.conf" 644 ifabsent
if installed_default "$CFG/kitty/kitty.conf"; then
    place "$HERE/defaults/kitty/theme.conf" "$CFG/kitty/theme.conf" 644 ifabsent
    place "$HERE/defaults/kitty/font.conf" "$CFG/kitty/font.conf" 644 ifabsent
    installed_default "$CFG/kitty/theme.conf" && THEMED+=(kitty)
fi
# App theming: Sleek Shell only recolours the apps whose config it installed above. Everything else
# (GTK, Qt/KDE, micro, your own kitty/rofi) stays off until you switch it on in Settings > Appearance > Apps.
if [ ! -e "$CFG/sleek-shell/app-themes.json" ] || owned "$CFG/sleek-shell/app-themes.json"; then
    {
        printf '{\n  "version": 1,\n  "scope": "selected",\n  "apps": {'
        sep=""
        for a in "${THEMED[@]}"; do printf '%s\n    "%s": { "mode": "inherit", "palette": "navy", "accent": "" }' "$sep" "$a"; sep=","; done
        printf '%s}\n}\n' "$( [ -n "$sep" ] && printf '\n  ')"
    } > "$TMP/app-themes.json"
    place "$TMP/app-themes.json" "$CFG/sleek-shell/app-themes.json" 644 ifabsent
fi
GEN["$CFG/kitty/theme.conf"]=1 GEN["$CFG/kitty/font.conf"]=1 GEN["$CFG/rofi/themes/rice.rasi"]=1 GEN["$CFG/sleek-shell/app-themes.json"]=1
ok "app theming enabled for: ${THEMED[*]:-nothing (your configs were left alone)}"

head1 "Calculator"
place "$HERE/calc/sleek-calc" "$BIN/sleek-calc" 755 managed
sed "s#@BINDIR@#$BIN#" "$HERE/calc/sleek-calc.desktop" > "$TMP/sleek-calc.desktop"
place "$TMP/sleek-calc.desktop" "$DATA_HOME/applications/sleek-calc.desktop" 644 managed
for f in Makefile README.md rofi-sleek-calc.c sleek_calc.py test_sleek_calc.py; do
    place "$HERE/calc/$f" "$DATA/calc/$f" 644 managed
done
if command -v make >/dev/null 2>&1 && command -v pkg-config >/dev/null 2>&1 && pkg-config --exists rofi glib-2.0 cairo 2>/dev/null; then
    if [ "$DRY" = 1 ]; then say "  would build the rofi plugin (make -C ${DATA/#$HOME/\~}/calc install)"
    elif mkdirs "$HOME/.local/lib/rofi" && make -s -C "$DATA/calc" PLUGINDIR="$HOME/.local/lib/rofi" install >"$TMP/make.log" 2>&1; then
        record_file "$(sha_of "$DATA/calc/sleekcalc.so")" "$DATA/calc/sleekcalc.so"
        record_file "$(sha_of "$HOME/.local/lib/rofi/sleekcalc.so")" "$HOME/.local/lib/rofi/sleekcalc.so"
        ok "rofi plugin built"
    else
        warn "the rofi plugin did not build; the calculator uses script mode (log: make -C ${DATA/#$HOME/\~}/calc)"
    fi
else
    say "  rofi development files not found: the calculator uses script mode (works, a little slower)"
fi
case ":$PATH:" in *":$BIN:"*) ;; *) warn "$BIN is not in PATH (SUPER+ALT+C uses the full path, so the keybind still works)" ;; esac

head1 "Fonts"
place "$HERE/assets/fonts/MaterialSymbolsRounded.ttf" "$DATA_HOME/fonts/sleek-shell/MaterialSymbolsRounded.ttf" 644 managed
place "$HERE/assets/fonts/LICENSE-MaterialSymbols.txt" "$DATA_HOME/fonts/sleek-shell/LICENSE-MaterialSymbols.txt" 644 managed
if command -v fc-cache >/dev/null 2>&1; then act "refresh the font cache" fc-cache -f "$DATA_HOME/fonts/sleek-shell"; fi

head1 "Wallpaper"
place "$HERE/assets/wallpapers/astronaut-planet.png" "$HOME/Pictures/Wallpapers/sleek-shell-astronaut.png" 644 ifabsent

head1 "Docs, greeter, uninstaller"
for f in README.md LICENSE CHANGELOG.md VERSION; do [ -f "$HERE/$f" ] && place "$HERE/$f" "$DATA/$f" 644 managed; done
place "$HERE/uninstall.sh" "$DATA/uninstall.sh" 755 managed
place_tree "$HERE/docs" "$DATA/docs"
place_tree "$HERE/greeter" "$DATA/greeter"
place_tree "$HERE/hypr" "$DATA/hypr"
remove_stale "$DATA"
ok "${DATA/#$HOME/\~}"

mkdirs "$DATA"
write_manifest "$MANIFEST"

head1 "$( [ "$DRY" = 1 ] && echo 'Dry run finished: nothing was changed' || echo 'Installed')"
if [ "$DRY" = 0 ]; then
    say "  manifest   ${MANIFEST/#$HOME/\~}"
    say "  uninstall  ${DATA/#$HOME/\~}/uninstall.sh"
    if [ "${XDG_CURRENT_DESKTOP:-}" = Hyprland ]; then
        say "  restart the shell:  pkill -x quickshell; hyprctl dispatch 'hl.dsp.exec_cmd(\"quickshell\")'"
    else
        say "  log out and pick the Hyprland session in your display manager"
    fi
    say "  optional login greeter (needs sudo, review first): ${DATA/#$HOME/\~}/greeter/install.sh --help"
fi
[ "$WARNINGS" = 0 ] || say "  $WARNINGS warning(s) above"
