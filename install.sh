#!/usr/bin/env bash
# Sleek Shell installer: one command from a minimal Arch Linux install to a working desktop.
#
#   ./install.sh                  install everything (asks for the few real choices, then once to confirm)
#   ./install.sh --dry-run        show the whole plan, including every sudo command, and change nothing
#   ./install.sh --check          report the system and what an install would do (read-only)
#   ./install.sh --yes            take the defaults for every choice and do not ask
#
# On Arch Linux and Arch-based distributions with systemd it installs and enables, with sudo: the
# packages (repositories, plus the AUR for the few that need it), the GPU driver, PipeWire, NetworkManager,
# Bluetooth, power profiles, the login screen and zsh. Then it installs the desktop into your home.
# Elsewhere it installs into your home only and lists the packages you need (docs/DISTROS.md).
#
# Choices (asked when you do not pass them; --yes and --dry-run take the default):
#   --browser firefox|chromium|vivaldi|brave|zen|chrome|epiphany|none     default: firefox
#   --greeter auto|sleek|keep     login screen: auto installs it when there is none and asks before
#                                 replacing another display manager (default: keep the other one)
#   --idle short|balanced|long|never      lock / screen off / suspend timeouts (default: balanced)
#   --lock-after MIN, --screen-off-after MIN, --suspend-after MIN       exact timeouts (0 = never)
#   --nvidia open|580xx|nouveau   override the NVIDIA driver choice (default: picked from the card)
# Other options:
#   --profile full|shell          shell = the Quickshell shell only, your Hyprland config is kept
#   --replace-hypr                replace an existing ~/.config/hypr (it is backed up first)
#   --keep-shell                  do not make zsh your login shell
#   --user-only                   no sudo: install into your home only (also --skip-system)
#   --ignore-deps                 with --user-only: install even when required programs are missing
#   --install-deps, --with-optional    other distributions: install the missing packages after asking
#   --help
# Replaced files go to ~/.local/share/sleek-shell-backups/; ~/.local/share/sleek-shell/uninstall.sh
# puts them back. Exit status: 0 ok, 1 error, 3 required programs missing (--check), 4 installed but a
# post-install check failed (see ~/.local/share/sleek-shell/install-report.txt).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"
# shellcheck source=lib/distro.sh
. "$HERE/lib/distro.sh"
# shellcheck source=lib/deps.sh
. "$HERE/lib/deps.sh"
# shellcheck source=lib/priv.sh
. "$HERE/lib/priv.sh"
# shellcheck source=lib/gpu.sh
. "$HERE/lib/gpu.sh"
# shellcheck source=lib/arch.sh
. "$HERE/lib/arch.sh"

VERSION="$(cat "$HERE/VERSION" 2>/dev/null || echo 0.0.0)"
PROFILE=full
REPLACE_HYPR=0
CHECK_ONLY=0
YES=0
IGNORE_DEPS=0
INSTALL_DEPS=0
WITH_OPTIONAL=0
USER_ONLY=0
KEEP_SHELL=0
BROWSER="" BROWSER_EXPLICIT=0
GREETER_CHOICE=auto
NVIDIA_MODE=auto
IDLE_PRESET="" IDLE_LOCK="" IDLE_OFF="" IDLE_SUSPEND=""

usage() { awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "${BASH_SOURCE[0]}"; }

need_val() { [ $# -ge 2 ] && [ -n "$2" ] || die "$1 needs a value (see --help)"; }
while [ $# -gt 0 ]; do
    case "$1" in
        --*=*) v="${1#*=}"; set -- "${1%%=*}" "$v" "${@:2}"; continue ;;
        --profile) need_val "$@"; PROFILE="$2"; shift ;;
        --browser) need_val "$@"; BROWSER="$2"; BROWSER_EXPLICIT=1; shift ;;
        --greeter) need_val "$@"; GREETER_CHOICE="$2"; shift ;;
        --idle) need_val "$@"; IDLE_PRESET="$2"; shift ;;
        --lock-after) need_val "$@"; IDLE_LOCK="$2"; shift ;;
        --screen-off-after) need_val "$@"; IDLE_OFF="$2"; shift ;;
        --suspend-after) need_val "$@"; IDLE_SUSPEND="$2"; shift ;;
        --nvidia) need_val "$@"; NVIDIA_MODE="$2"; shift ;;
        --replace-hypr) REPLACE_HYPR=1 ;;
        --keep-shell) KEEP_SHELL=1 ;;
        --user-only|--skip-system) USER_ONLY=1 ;;
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
case "$GREETER_CHOICE" in auto|sleek|keep) ;; *) die "unknown --greeter '$GREETER_CHOICE' (auto, sleek or keep)" ;; esac
case "$NVIDIA_MODE" in auto|open|580xx|nouveau) ;; *) die "unknown --nvidia '$NVIDIA_MODE' (open, 580xx or nouveau)" ;; esac
case "$IDLE_PRESET" in ""|short|balanced|long|never|custom) ;; *) die "unknown --idle '$IDLE_PRESET' (short, balanced, long or never)" ;; esac
if [ -n "$BROWSER" ] && [ "$BROWSER" != none ] && [ -z "$(browser_field "$BROWSER" 1)" ]; then
    die "unknown --browser '$BROWSER' ($(browser_ids | tr '\n' ' ')none)"
fi
[ -z "$IDLE_LOCK" ] || idle_valid "$IDLE_LOCK" "$IDLE_LOCK_CHOICES" || die "--lock-after must be one of: $IDLE_LOCK_CHOICES (minutes, 0 = never)"
[ -z "$IDLE_OFF" ] || idle_valid "$IDLE_OFF" "$IDLE_OFF_CHOICES" || die "--screen-off-after must be one of: $IDLE_OFF_CHOICES (minutes, 0 = never)"
[ -z "$IDLE_SUSPEND" ] || idle_valid "$IDLE_SUSPEND" "$IDLE_SUSPEND_CHOICES" || die "--suspend-after must be one of: $IDLE_SUSPEND_CHOICES (minutes, 0 = never)"

[ "$(id -u)" != 0 ] || die "run as your own user, not root: Sleek Shell installs into your home directory and asks for sudo itself"
[ -n "${HOME:-}" ] && [ -d "$HOME" ] || die "HOME is not set"
{ [ "$YES" = 1 ] || [ "$DRY" = 1 ] || [ "$CHECK_ONLY" = 1 ]; } && NONINTERACTIVE=1

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DATA="$DATA_HOME/sleek-shell"
BIN="$HOME/.local/bin"
MANIFEST="$DATA/manifest.tsv"
REPORT="$DATA/install-report.txt"
SYSLOG="$DATA/system-changes.log"
BACKUP_DIR="$DATA_HOME/sleek-shell-backups/$(date +%Y%m%d-%H%M%S)"
TMP=""
USER_STARTED=0 USER_DONE=0 SYSLOG_DONE=0

# The manifest must describe what is on disk even when the run stops half way (an error, Ctrl+C):
# entries of the previous install that still exist are kept next to what this run placed.
on_exit() {
    local rc=$? p
    priv_stop
    if [ "$USER_STARTED" = 1 ] && [ "$USER_DONE" = 0 ] && [ "$DRY" = 0 ]; then
        for p in "${!OLD_SHA[@]}"; do
            [ -n "${NEW_FILES[$p]+x}" ] || { [ -e "$p" ] && NEW_FILES["$p"]="${OLD_SHA[$p]}"; }
        done
        mkdir -p "$DATA" && write_manifest "$MANIFEST" 2>/dev/null || true
        printf '%sThe install stopped before it finished.%s Re-run ./install.sh: finished steps are skipped.\n' "$C_Y" "$C_0" >&2
    fi
    write_syslog
    [ -z "$TMP" ] || rm -rf "$TMP"
    exit "$rc"
}
write_syslog() {
    [ "$SYSLOG_DONE" = 0 ] && [ "$DRY" = 0 ] && [ "${#SYS_CHANGES[@]}" -gt 0 ] || return 0
    SYSLOG_DONE=1
    mkdir -p "$DATA" 2>/dev/null || return 0
    { printf '%s  Sleek Shell %s\n' "$(date '+%Y-%m-%d %H:%M')" "$VERSION"; printf '  %s\n' "${SYS_CHANGES[@]}"; } >> "$SYSLOG" 2>/dev/null || true
}
trap on_exit EXIT
trap 'exit 130' INT TERM

wrap() { awk -v ind="$1" '{ for (i = 1; i <= NF; i++) { if (len + length($i) > 76) { printf "\n"; len = 0 } if (len == 0) { printf "%s", ind } else { printf " " } printf "%s", $i; len += length($i) + 1 } } END { if (len) printf "\n" }'; }
minutes() { [ "$1" = 0 ] && echo never || echo "$1 min"; }

# ------------------------------------------------------------------------------------- detect
detect_distro
SYSTEM=0 SYSTEM_WHY=""
if [ "$USER_ONLY" = 1 ]; then SYSTEM_WHY="--user-only: nothing outside your home is changed"
elif [ "$DISTRO_FAMILY" != arch ]; then SYSTEM_WHY="$DISTRO_NAME is not Arch-based: packages and services are listed for you to install"
elif [ ! -d "$SYS_ROOT/run/systemd/system" ]; then SYSTEM_WHY="systemd is not running (a chroot?): run ./install.sh again after booting into the installed system"
elif ! command -v pacman >/dev/null 2>&1; then SYSTEM_WHY="pacman not found"
else SYSTEM=1; fi

DM_NOW="$(display_manager)"
gpu_scan
head1 "Sleek Shell $VERSION"
say "  distro        $DISTRO_NAME (family: $DISTRO_FAMILY, $DISTRO_SUPPORT)"
say "  init          $(init_system)"
say "  login screen  $DM_NOW$( [ "$(greetd_uses_sleek)" = yes ] && echo ' (Sleek Shell greeter)')"
while IFS= read -r l; do say "  graphics      $l"; done < <(gpu_describe)
say "  session       ${XDG_CURRENT_DESKTOP:-none}${WAYLAND_DISPLAY:+ (Wayland)}"
say "  system setup  $( [ "$SYSTEM" = 1 ] && echo "yes (sudo)" || echo "no: $SYSTEM_WHY")"
say "  profile       $PROFILE$( [ "$DRY" = 1 ] && echo ', dry run')$( [ "$CHECK_ONLY" = 1 ] && echo ', check only')"
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

if [ "$DISTRO_FAMILY" = arch ]; then
    [ "$INSTALL_DEPS" = 0 ] || say "  note: --install-deps is not needed on $DISTRO_NAME: ./install.sh installs everything itself"
    if [ "$SYSTEM" = 0 ] && [ "$deps_ok" = 0 ]; then
        say "  ./install.sh installs the missing packages on a booted Arch system with systemd (without --user-only)."
    fi
else
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
fi

if [ "$deps_ok" = 0 ] && [ "$SYSTEM" = 0 ] && [ "$CHECK_ONLY" = 0 ]; then
    if [ "$IGNORE_DEPS" = 1 ] || [ "$DRY" = 1 ]; then warn "required dependencies are missing; continuing ($( [ "$DRY" = 1 ] && echo dry run || echo --ignore-deps))"
    else die "required dependencies are missing (install them, or pass --ignore-deps to install the files anyway)"; fi
fi

# ------------------------------------------------------------------------------------- choices
if [ "$SYSTEM" = 1 ]; then
    gpu_plan "$NVIDIA_MODE"

    if [ -z "$BROWSER" ]; then
        def=firefox cur="$(default_browser || true)"
        mapfile -t have < <(browsers_installed)
        if [ -n "$cur" ]; then
            def=none
            for id in "${have[@]}"; do [[ " $(browser_field "$id" 4) " == *" $cur "* ]] && { def="$id"; break; }; done
        elif [ "${#have[@]}" -gt 0 ]; then def="${have[0]}"; fi
        opts=()
        while IFS= read -r id; do
            pkg="$(browser_field "$id" 3)" tag=""
            if [[ " ${have[*]} " == *" $id "* ]]; then tag=" (installed)"
            elif ! in_repos "$pkg"; then tag=" (from the AUR)"; fi
            opts+=("$id|$(browser_field "$id" 2)$tag")
        done < <(browser_ids)
        if [ -n "$cur" ]; then opts+=("none|No browser (keep $cur)"); else opts+=("none|No browser"); fi
        [ "$NONINTERACTIVE" = 0 ] && prompt_open && BROWSER_EXPLICIT=1
        choose BROWSER "Web browser" "$def" "${opts[@]}"
    fi

    greeter_decide "$GREETER_CHOICE"
fi

HAS_IDLE=0
[ -n "$(idle_current idleLockMin "")" ] && HAS_IDLE=1
if has_battery; then LAPTOP=1; else LAPTOP=0; fi
idle_preset() {   # idle_preset NAME: sets P_LOCK P_OFF P_SUSPEND, and on laptops the battery set P_BAT (P_BSEP 1/0, "" = keep)
    P_BAT="" P_BSEP=""
    case "$1" in
        short)    P_LOCK=5;  P_OFF=10; P_SUSPEND=$( [ "$LAPTOP" = 1 ] && echo 15 || echo 0); P_BAT="2 5 15" ;;
        balanced) P_LOCK=10; P_OFF=15; P_SUSPEND=$( [ "$LAPTOP" = 1 ] && echo 30 || echo 0); P_BAT="5 10 15" ;;
        long)     P_LOCK=15; P_OFF=30; P_SUSPEND=$( [ "$LAPTOP" = 1 ] && echo 60 || echo 0); P_BAT="10 15 30" ;;
        never)    P_LOCK=0;  P_OFF=0;  P_SUSPEND=0; P_BSEP=0 ;;
        *)        P_LOCK="$(idle_current idleLockMin 10)"; P_OFF="$(idle_current idleScreenOffMin 15)"; P_SUSPEND="$(idle_current idleSuspendMin 0)" ;;
    esac
    if [ -n "$P_BAT" ]; then
        if [ "$LAPTOP" = 1 ]; then P_BSEP=1; else P_BAT="" P_BSEP=0; fi
    fi
}
bat_text() {
    local a b c
    [ -n "$P_BAT" ] || return 0
    read -r a b c <<< "$P_BAT"
    echo " (on battery: lock after $a min, screen off after $b min, suspend after $c min)"
}
IDLE_WRITE=1
if [ -z "$IDLE_PRESET$IDLE_LOCK$IDLE_OFF$IDLE_SUSPEND" ]; then
    idle_preset keep; k="lock $(minutes "$P_LOCK"), screen off $(minutes "$P_OFF"), suspend $(minutes "$P_SUSPEND")"
    opts=()
    [ "$HAS_IDLE" = 1 ] && opts+=("keep|Keep your current timeouts: $k")
    for n in short balanced long; do
        idle_preset "$n"; opts+=("$n|${n^}: lock after $P_LOCK min, screen off after $P_OFF min, suspend $(minutes "$P_SUSPEND")$(bat_text)")
    done
    opts+=("never|Never: no automatic lock, screen off or suspend")
    choose IDLE_PRESET "When you are away (lock, screen off, suspend)" "$( [ "$HAS_IDLE" = 1 ] && echo keep || echo balanced)" "${opts[@]}"
fi
[ "$IDLE_PRESET" = keep ] && IDLE_WRITE=0
[ "$IDLE_PRESET" = custom ] && IDLE_PRESET=keep
idle_preset "${IDLE_PRESET:-keep}"
[ -z "$IDLE_LOCK" ] || { P_LOCK="$IDLE_LOCK"; IDLE_WRITE=1; }
[ -z "$IDLE_OFF" ] || { P_OFF="$IDLE_OFF"; IDLE_WRITE=1; }
[ -z "$IDLE_SUSPEND" ] || { P_SUSPEND="$IDLE_SUSPEND"; IDLE_WRITE=1; }

if [ "$SYSTEM" = 1 ]; then
    WANT_GREETD=0
    case "$GREETER_ACTION" in install|replace) WANT_GREETD=1 ;; esac
    arch_plan "$BROWSER" "$WANT_GREETD"
fi

# ------------------------------------------------------------------------------------- user plan
load_old_manifest "$MANIFEST"

# A ~/.config/hypr that Hyprland wrote itself on its first start (no config yet) is not yours: replace it.
hypr_autogenerated() {
    local d="$CFG/hypr" f n=0
    [ -d "$d" ] || return 1
    while IFS= read -r -d '' f; do
        case "${f##*/}" in
            hyprland.conf) grep -qE '^[[:space:]]*autogenerated[[:space:]]*=[[:space:]]*1' "$f" || return 1 ;;
            hyprland.lua) grep -qE 'autogenerated[[:space:]]*=[[:space:]]*true' "$f" || return 1 ;;
            *) return 1 ;;
        esac
        n=$((n + 1))
    done < <(find "$d" -type f -print0)
    [ "$n" -gt 0 ]
}
HYPR_ACTION=skip HYPR_AUTOGEN=0
if [ "$PROFILE" = full ]; then
    if [ ! -e "$CFG/hypr" ]; then HYPR_ACTION=install
    elif owned_under "$CFG/hypr"; then HYPR_ACTION=upgrade
    elif [ "$REPLACE_HYPR" = 1 ]; then HYPR_ACTION=replace
    elif hypr_autogenerated; then HYPR_ACTION=replace HYPR_AUTOGEN=1
    else HYPR_ACTION=keep; fi
fi
QS_ACTION=install
if [ -e "$CFG/quickshell" ]; then
    if owned_under "$CFG/quickshell"; then QS_ACTION=upgrade; else QS_ACTION=replace; fi
fi
# ~/.zshrc: installed when absent, or when it only holds what zsh-newuser-install wrote (comments)
ZSHRC_TRIVIAL=0
if [ -f "$HOME/.zshrc" ] && ! owned "$HOME/.zshrc" && ! grep -qvE '^[[:space:]]*(#.*)?$' "$HOME/.zshrc"; then ZSHRC_TRIVIAL=1; fi

# ------------------------------------------------------------------------------------- plan
head1 "Plan"
if [ "$SYSTEM" = 1 ]; then
    say "  ${C_B}System (sudo)${C_0}"
    say "  packages      full upgrade plus ${#PKG_REPO[@]} packages from the repositories (already installed ones are skipped)"
    [ "${#PKG_AUR[@]}" = 0 ] || say "  AUR           ${PKG_AUR[*]}"
    [ "${#PKG_REMOVE[@]}" = 0 ] || say "  remove        ${PKG_REMOVE[*]}"
    say "  graphics      $GPU_KIND$( [ -n "$GPU_NVIDIA_DRIVER" ] && echo ", NVIDIA driver: $GPU_NVIDIA_DRIVER")"
    for n in "${GPU_NOTES[@]}"; do say "                $n"; done
    say "  services      PipeWire (user), NetworkManager, Bluetooth$(pkg_installed power-profiles-daemon || [[ " ${PKG_REPO[*]} " == *" power-profiles-daemon "* ]] && echo ', power-profiles-daemon')"
    case "$GREETER_ACTION" in
        install) say "  login screen  Sleek Shell greeter (greetd), enabled for the next boot" ;;
        refresh) say "  login screen  Sleek Shell greeter: refreshed" ;;
        replace) say "  login screen  Sleek Shell greeter replaces $GREETER_OLD (disabled, not removed)" ;;
        keep)    say "  login screen  $DM_NOW (kept)$( [ "$DM_NOW" = none ] && echo ': start Hyprland from the console with: start-hyprland')" ;;
    esac
    say "  browser       $( [ "$BROWSER" = none ] && echo 'none (kept as it is)' || browser_field "$BROWSER" 2)"
    say "  login shell   $( [ "$KEEP_SHELL" = 1 ] && echo 'kept (--keep-shell)' || echo 'zsh (only if it is bash now)')"
    for n in "${ARCH_NOTES[@]}"; do say "  note          $n"; done
    say "  ${C_B}Your home${C_0}"
fi
say "  ~/.config/quickshell        $QS_ACTION$( [ "$QS_ACTION" = replace ] && echo ' (your current one is backed up first)')"
case "$HYPR_ACTION" in
    install) say "  ~/.config/hypr              install" ;;
    upgrade) say "  ~/.config/hypr              upgrade (monitors.lua, custom_binds.lua, user.lua are kept)" ;;
    replace) say "  ~/.config/hypr              replace ($( [ "$HYPR_AUTOGEN" = 1 ] && echo 'it only holds the config Hyprland generated on its first start; ')backed up first)" ;;
    keep)    say "  ~/.config/hypr              keep yours (pass --replace-hypr to use Sleek Shell's; see docs/CONFIG.md)" ;;
    skip)    say "  ~/.config/hypr              not touched (profile shell)" ;;
esac
say "  ~/.zshrc                    $( if [ ! -e "$HOME/.zshrc" ]; then echo install; elif [ "$ZSHRC_TRIVIAL" = 1 ]; then echo 'replace the empty one zsh created (backed up)'; elif owned "$HOME/.zshrc"; then echo upgrade; else echo 'keep yours'; fi)"
say "  rofi / kitty defaults       only where you have no config yet"
say "  idle                        $( [ "$IDLE_WRITE" = 0 ] && echo 'keep your current timeouts' || echo "lock $(minutes "$P_LOCK"), screen off $(minutes "$P_OFF"), suspend $(minutes "$P_SUSPEND")$(bat_text)")"
say "  calculator, icon font, wallpaper, docs, greeter files, uninstaller"
say "  backups                     ${BACKUP_DIR/#$HOME/\~}/ (only if something is replaced)"

if [ "$CHECK_ONLY" = 1 ]; then
    if [ "$SYSTEM" = 1 ] && [ "${#PKG_REPO[@]}" -gt 0 ]; then
        say ""; say "  packages ./install.sh installs or keeps (pacman --needed):"; printf '%s\n' "${PKG_REPO[*]}" | wrap "    "
    fi
    [ -f "$MANIFEST" ] && say "
  installed: $(awk -F'\t' '$1=="version"{print $2}' "$MANIFEST") ($MANIFEST)"
    [ "$deps_ok" = 1 ] && exit 0 || exit 3
fi

if [ "$DRY" = 0 ] && [ "$YES" = 0 ]; then
    prompt_open || die "not a terminal: re-run with --yes to accept the defaults (or --dry-run to preview)"
    choose_yesno "Install now?" yes || { say "Nothing changed."; exit 0; }
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sleek-shell-install.XXXXXX")"

# ------------------------------------------------------------------------------------- system
if [ "$SYSTEM" = 1 ]; then
    priv_init
    head1 "Packages"
    arch_install_packages
    arch_install_aur
    if [ "$DRY" = 0 ]; then
        deps_ok=1
        check_deps "$DISTRO_FAMILY" >"$TMP/deps.log" || deps_ok=0
        if [ "$deps_ok" = 0 ]; then
            grep MISSING "$TMP/deps.log" | grep -v optional >&2 || true
            warn "required programs are still missing after installing packages: the desktop may not start (see above)"
        fi
    fi
    head1 "Graphics"
    arch_gpu_apply
fi

# ------------------------------------------------------------------------------------- home
USER_STARTED=1
head1 "Quickshell"
[ "$QS_ACTION" = replace ] && backup_away "$CFG/quickshell"
place_tree "$HERE/quickshell" "$CFG/quickshell"
remove_stale "$CFG/quickshell"
ok "shell files ($COUNT_FILES)"

HYPR_VERIFY=""
if [ "$HYPR_ACTION" != skip ]; then
    head1 "Hyprland"
    if [ "$HYPR_ACTION" = keep ]; then
        say "  kept your ~/.config/hypr. Sleek Shell's config is in ${DATA/#$HOME/\~}/hypr for reference."
        say "  The minimum your config needs is in docs/CONFIG.md (autostart quickshell, awww-daemon, cliphist)."
    else
        [ "$HYPR_ACTION" = replace ] && backup_away "$CFG/hypr"
        [ "$HYPR_AUTOGEN" = 1 ] && say "  (it was the default config Hyprland writes on its first start)"
        n0=$COUNT_FILES
        place_tree "$HERE/hypr" "$CFG/hypr"
        remove_stale "$CFG/hypr"
        ok "Hyprland config ($((COUNT_FILES - n0)) files)"
        if command -v Hyprland >/dev/null 2>&1 && [ "$DRY" = 0 ]; then
            if Hyprland --verify-config -c "$CFG/hypr/hyprland.lua" >"$TMP/verify.log" 2>&1 && grep -q 'config ok' "$TMP/verify.log"; then
                HYPR_VERIFY=ok; ok "Hyprland --verify-config: config ok"
            else
                HYPR_VERIFY=fail; warn "Hyprland --verify-config reported problems:"; tail -n 5 "$TMP/verify.log" | sed 's/^/        /' >&2
            fi
        fi
    fi
fi

head1 "Shell and defaults"
[ "$ZSHRC_TRIVIAL" = 1 ] && backup_away "$HOME/.zshrc"
place "$HERE/defaults/zsh/zshrc" "$HOME/.zshrc" 644 ifabsent
# Files Sleek Shell rewrites at runtime (theme colours, fonts): adopted when they carry its header
GEN["$CFG/kitty/theme.conf"]=1 GEN["$CFG/kitty/font.conf"]=1 GEN["$CFG/rofi/themes/rice.rasi"]=1 GEN["$CFG/sleek-shell/app-themes.json"]=1
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

head1 "Fonts"
place "$HERE/assets/fonts/MaterialSymbolsRounded.ttf" "$DATA_HOME/fonts/sleek-shell/MaterialSymbolsRounded.ttf" 644 managed
place "$HERE/assets/fonts/LICENSE-MaterialSymbols.txt" "$DATA_HOME/fonts/sleek-shell/LICENSE-MaterialSymbols.txt" 644 managed
if command -v fc-cache >/dev/null 2>&1; then act "refresh the font cache" fc-cache -f "$DATA_HOME/fonts/sleek-shell"; fi

head1 "Wallpaper"
place "$HERE/assets/wallpapers/astronaut-planet.png" "$HOME/Pictures/Wallpapers/sleek-shell-astronaut.png" 644 ifabsent
ok "default wallpaper in ~/Pictures/Wallpapers"

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
USER_DONE=1

# ------------------------------------------------------------------------------------- system 2
if [ "$SYSTEM" = 1 ]; then
    head1 "Login screen"
    arch_greeter
    head1 "Services"
    arch_services
    if [ "$KEEP_SHELL" = 0 ]; then arch_login_shell; else ok "login shell: $(login_shell) (--keep-shell)"; fi
    if [ "$DRY" = 0 ] && command -v xdg-user-dirs-update >/dev/null 2>&1 && [ ! -f "$CFG/user-dirs.dirs" ]; then
        xdg-user-dirs-update && ok "home folders (Documents, Downloads, Pictures, ...)" || true
    fi
fi

head1 "Preferences"
if [ "$IDLE_WRITE" = 1 ]; then read -r B_LOCK B_OFF B_SUSPEND <<< "${P_BAT:-}"; apply_idle "$P_LOCK" "$P_OFF" "$P_SUSPEND" "$P_BSEP" "${B_LOCK:-}" "${B_OFF:-}" "${B_SUSPEND:-}"; else ok "idle: your current timeouts are kept"; fi
if [ "$SYSTEM" = 1 ] || { [ "$BROWSER_EXPLICIT" = 1 ] && [ -n "$BROWSER" ]; }; then apply_browser "$BROWSER" "$BROWSER_EXPLICIT"; fi
case ":$PATH:" in *":$BIN:"*) ;; *) say "  ~/.local/bin is added to PATH by Hyprland and the zsh config from the next login" ;; esac

# ------------------------------------------------------------------------------------- verify
VERIFY_LINES=() VERIFY_FAILED=0
if [ "$DRY" = 0 ]; then
    head1 "Checking the result"
    [ "$SYSTEM" = 1 ] && arch_verify
    case "$HYPR_VERIFY" in
        ok) VERIFY_LINES+=("ok    Hyprland --verify-config") ;;
        fail) VERIFY_LINES+=("FAIL  Hyprland --verify-config (see the messages above)"); VERIFY_FAILED=$((VERIFY_FAILED + 1)) ;;
    esac
    [ "$SYSTEM" = 1 ] || ok "files installed (system checks skipped: $SYSTEM_WHY)"
    write_syslog
    {
        printf 'Sleek Shell %s install report, %s\n\n' "$VERSION" "$(date '+%Y-%m-%d %H:%M')"
        printf 'distro:   %s (%s)\n' "$DISTRO_NAME" "$DISTRO_FAMILY"
        gpu_describe | sed 's/^/graphics: /'
        printf 'profile:  %s\nsystem:   %s\n' "$PROFILE" "$( [ "$SYSTEM" = 1 ] && echo yes || echo "no ($SYSTEM_WHY)")"
        [ "$SYSTEM" = 0 ] || printf 'browser:  %s\nlogin:    %s\n' "$BROWSER" "$GREETER_ACTION${GREETER_OLD:+ (was $GREETER_OLD)}"
        printf 'idle:     lock %s, screen off %s, suspend %s\n' "$(minutes "$(idle_current idleLockMin 10)")" "$(minutes "$(idle_current idleScreenOffMin 15)")" "$(minutes "$(idle_current idleSuspendMin 0)")"
        if [ "$(idle_current idleBatterySeparate 0)" = 1 ]; then
            printf 'battery:  lock %s, screen off %s, suspend %s\n' "$(minutes "$(idle_current idleBatteryLockMin 5)")" "$(minutes "$(idle_current idleBatteryScreenOffMin 10)")" "$(minutes "$(idle_current idleBatterySuspendMin 15)")"
        fi
        if [ "${#SYS_CHANGES[@]}" -gt 0 ]; then printf '\nSystem changes:\n'; printf '  %s\n' "${SYS_CHANGES[@]}"; fi
        if [ "${#VERIFY_LINES[@]}" -gt 0 ]; then printf '\nChecks:\n'; printf '  %s\n' "${VERIFY_LINES[@]}"; fi
        printf '\nWarnings: %d\n' "$WARNINGS"
    } > "$REPORT"
fi

head1 "$( [ "$DRY" = 1 ] && echo 'Dry run finished: nothing was changed' || echo 'Installed')"
if [ "$DRY" = 0 ]; then
    say "  report     ${REPORT/#$HOME/\~}"
    say "  uninstall  ${DATA/#$HOME/\~}/uninstall.sh"
    if [ "$SYSTEM" = 1 ] && [ "${#SYS_CHANGES[@]}" -gt 0 ]; then
        say "  ${C_B}Reboot now${C_0} to start the new drivers, services and login screen: systemctl reboot"
    elif [ "${XDG_CURRENT_DESKTOP:-}" = Hyprland ]; then
        say "  restart the shell:  pkill -x quickshell; hyprctl dispatch 'hl.dsp.exec_cmd(\"quickshell\")'"
    else
        say "  log out and pick the Hyprland session in your display manager"
    fi
    [ "$SYSTEM" = 1 ] || say "  login greeter (needs sudo, review first): ${DATA/#$HOME/\~}/greeter/install.sh --help"
fi
[ "$WARNINGS" = 0 ] || say "  $WARNINGS warning(s) above"
if [ "$VERIFY_FAILED" -gt 0 ]; then
    say "  ${C_R}$VERIFY_FAILED check(s) failed${C_0}: see ${REPORT/#$HOME/\~} and docs/TROUBLESHOOTING.md"
    exit 4
fi
exit 0
