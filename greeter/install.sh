#!/usr/bin/env bash
# Sleek Shell greeter installer (greetd + Hyprland + Quickshell).
#
#   sudo ./install.sh              install greetd + the greeter files. Changes NOTHING about how you log in.
#   sudo ./install.sh --test       print the safe manual test (greeter on VT7, your login untouched)
#   sudo ./install.sh --enable     make the greeter the login screen from the next boot (asks first; does not start it)
#   sudo ./install.sh --sync       re-copy your current theme, wallpaper, avatar, monitor and keyboard layout
#   sudo ./install.sh --enable --replace   as --enable, but a display manager that is already disabled and
#                                  only still running until the reboot does not block it (used by the main
#                                  installer after it disabled the old display manager with your consent)
#   sudo ./uninstall.sh            roll back (see that script)
#
# Safety:
#   * never starts or stops greetd. greetd.service conflicts with getty@tty1, so starting it while you are
#     logged in on tty1 would end that login. --enable only takes effect after a reboot.
#   * a /etc/greetd/config.toml that is not Sleek Shell's is only replaced by --enable, after you confirm,
#     and it is backed up next to it first. Install writes the greeter config to /etc/greetd/sleek-shell.toml;
#     it rewrites config.toml only when that already is the Sleek Shell config (so it matches the new files).
#   * files are read from your home as you (not as root), and the new greeter files are checked with
#     Hyprland --verify-config before anything points at them; on failure the previous files are put back.
#   * if the greetd package enables greetd.service on install (some distros do), it is disabled again.
#   * --enable refuses if another display manager is enabled or running (with --replace: enabled), or if no
#     TTY fallback exists.
#   * PAM is not modified: the distro's greetd package ships /etc/pam.d/greetd.
#   * only the clock24h preference is copied from your settings.json (the copy is world-readable).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# SLEEK_TEST_ROOT: fixture tests only (tests/greeter.sh). Every system path is prefixed with it, root is not
# required and file ownership is not changed. It must be a directory under /tmp.
ROOT="${SLEEK_TEST_ROOT:-}"
if [ -n "$ROOT" ]; then
    case "$ROOT" in /tmp/?*) [ -d "$ROOT" ] || { echo "error: SLEEK_TEST_ROOT does not exist" >&2; exit 1; } ;;
        *) echo "error: SLEEK_TEST_ROOT must be a directory under /tmp" >&2; exit 1 ;; esac
fi
DEST=$ROOT/etc/greetd/sleek-shell
CACHE=$ROOT/var/cache/sleek-shell-greeter
CONF=$ROOT/etc/greetd/config.toml
STAGED=$ROOT/etc/greetd/sleek-shell.toml
TESTCONF=$ROOT/etc/greetd/sleek-shell-test.toml
STATE="$DEST/state"
TS=$(date +%Y%m%d-%H%M%S)
KNOWN_DMS="sddm gdm gdm3 lightdm lxdm ly plasmalogin cosmic-greeter xdm slim nodm emptty entrance lemurs"

MODE=
ASSUME_YES=0
REPLACE=0
for a in "$@"; do
    case "$a" in
        --yes|-y) ASSUME_YES=1; continue ;;
        --replace) REPLACE=1; continue ;;
        -h|--help) sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        install|--install) m=install ;;
        --test|--enable|--sync) m="$a" ;;
        *) echo "error: unknown option $a" >&2; exit 1 ;;
    esac
    [ -z "$MODE" ] || [ "$MODE" = "$m" ] || { echo "error: give only one of --install, --test, --enable, --sync" >&2; exit 1; }
    MODE="$m"
done
MODE="${MODE:-install}"

die() { echo "error: $*" >&2; exit 1; }
say() { echo "==> $*"; }
warn() { echo "warning: $*" >&2; }

[ "$(id -u)" = 0 ] || [ -n "$ROOT" ] || die "run with sudo"
{ [ -d /run/systemd/system ] || [ -n "$ROOT" ]; } && command -v systemctl >/dev/null || die "systemd is required (greetd.service and logind)"

need_user() {
    USER_NAME="${SUDO_USER:-${DOAS_USER:-}}"
    [ -n "$USER_NAME" ] && [ "$USER_NAME" != root ] || die "run with sudo (or doas) from your normal user account: your theme is copied from it"
    USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6 || true)"
    [ -n "$USER_HOME" ] && [ -d "$USER_HOME" ] || die "cannot find the home directory of $USER_NAME"
}

greeter_user() {
    for u in greeter _greetd greetd; do id "$u" >/dev/null 2>&1 && { echo "$u"; return; }; done
    return 1
}

is_ours() { [ -f "$1" ] && grep -q -e 'sleek-shell' -e 'sleak-shell' -e 'sleakos' "$1"; }
greetd_enabled() { case "$(systemctl is-enabled greetd.service 2>/dev/null)" in enabled|enabled-runtime|alias) return 0 ;; esac; return 1; }
greetd_active() { systemctl is-active --quiet greetd.service 2>/dev/null; }

# Other display managers that are enabled or running (one per line). greetd itself is not listed.
# other_dms enabled: only the enabled ones (with --replace a display manager that still runs this boot but
# is already disabled does not block: it is gone after the reboot).
other_dms() {
    {
        if [ -L "$ROOT/etc/systemd/system/display-manager.service" ]; then
            t="$(basename "$(readlink -f "$ROOT/etc/systemd/system/display-manager.service")")"
            [ "$t" = greetd.service ] || echo "$t"
        fi
        for d in $KNOWN_DMS; do
            find "$ROOT/etc/systemd/system" -path '*.wants/*' \( -name "$d.service" -o -name "$d@*.service" \) -exec test -e {} \; -printf '%f\n' 2>/dev/null || true
            [ "${1:-}" = enabled ] || systemctl list-units --no-legend --plain --state=active "$d.service" "$d@*.service" 2>/dev/null | awk '{print $1}' || true
        done
    } | sort -u
}

# Package installs keep the package manager's own confirmation prompt.
install_greetd() {
    if command -v greetd >/dev/null; then say "greetd already installed"; return; fi
    if command -v pacman >/dev/null; then pacman -S --needed greetd
    elif command -v dnf >/dev/null; then dnf install greetd
    elif command -v apt-get >/dev/null; then apt-get install greetd
    elif command -v zypper >/dev/null; then zypper install greetd
    else die "unknown package manager: install greetd yourself, then re-run"; fi
    command -v greetd >/dev/null || die "greetd was not installed (nothing else changed)"
}

# system_font FAMILY: installed outside any home directory (the greeter account cannot read yours)
system_font() { grep -qE "^/usr/(local/)?share/fonts/[^:]*: ([^:]*,)?$1(,|\$)" <<<"$(fc-list : family file 2>/dev/null || true)"; }

install_font() {
    if system_font Inter; then say "Inter font already installed system-wide"
    else
        local ok=1
        if command -v pacman >/dev/null; then pacman -S --needed inter-font || ok=0
        elif command -v dnf >/dev/null; then dnf install rsms-inter-fonts || ok=0
        elif command -v apt-get >/dev/null; then apt-get install fonts-inter || ok=0
        elif command -v zypper >/dev/null; then zypper install inter-fonts || ok=0
        else ok=0; fi
        [ "$ok" = 1 ] || say "could not install the Inter font system-wide; the greeter will use Noto Sans"
    fi
    if system_font "JetBrainsMono Nerd Font"; then say "JetBrainsMono Nerd Font already installed system-wide"; return; fi
    if command -v pacman >/dev/null && pacman -S --needed ttf-jetbrains-mono-nerd; then return; fi
    warn "JetBrainsMono Nerd Font is not installed system-wide: the greeter's icons will show as boxes."
    warn "Install it to /usr/local/share/fonts (see docs/DISTROS.md), run fc-cache -f, then --sync."
}

# System keyboard layout (localectl / X11 settings) for typing the password; the greeter defaults to "us".
write_keyboard() {
    local st l v o m clean='A-Za-z0-9_,:+().-'
    st="$(localectl status 2>/dev/null || true)"
    l="$(sed -n 's/^ *X11 Layout: //p' <<<"$st" | tr -cd "$clean")"
    v="$(sed -n 's/^ *X11 Variant: //p' <<<"$st" | tr -cd "$clean")"
    o="$(sed -n 's/^ *X11 Options: //p' <<<"$st" | tr -cd "$clean")"
    m="$(sed -n 's/^ *X11 Model: //p' <<<"$st" | tr -cd "$clean")"
    if [ -z "$l" ]; then rm -f "$DEST/keyboard.lua"; say "no system keyboard layout set (localectl); the greeter uses us"; return; fi
    {
        echo "-- generated by install.sh from localectl ($TS); re-run install.sh --sync after changing it"
        echo "return {"
        echo "    kb_layout = \"$l\","
        [ -n "$v" ] && echo "    kb_variant = \"$v\","
        [ -n "$o" ] && echo "    kb_options = \"$o\","
        [ -n "$m" ] && echo "    kb_model = \"$m\","
        echo "}"
    } > "$DEST/keyboard.lua"
    chmod 644 "$DEST/keyboard.lua"
    say "greeter keyboard layout: $l${v:+ ($v)}"
}

# Copy a file out of the user's home with the user's own permissions, so a symlink there cannot make
# root copy a protected file (e.g. /etc/shadow) into the world-readable $DEST. $1 source, $2 target.
ucopy() {
    local tmp
    tmp="$(mktemp "$2.XXXXXX")"
    if runuser -u "$USER_NAME" -- cat -- "$1" > "$tmp" 2>/dev/null; then chmod 644 "$tmp"; mv -f "$tmp" "$2"
    else rm -f "$tmp"; warn "could not read $1 as $USER_NAME; skipped"; return 1; fi
}

# The greeter only reads clock24h; copy nothing else from settings.json into the world-readable $DEST.
write_greeter_settings() {
    local c24=false
    if runuser -u "$USER_NAME" -- cat -- "$USER_HOME/.config/sleek-shell/settings.json" 2>/dev/null \
        | grep -Eq '"clock24h"[[:space:]]*:[[:space:]]*true'; then c24=true; fi
    printf '{ "clock24h": %s }\n' "$c24" > "$DEST/settings.json"
    chmod 644 "$DEST/settings.json"
}

# Keep the current $DEST so a failed verification can put it back (a running or enabled greetd uses it).
snapshot_dest() { rm -rf "$DEST.prev"; if [ -d "$DEST" ]; then cp -a "$DEST" "$DEST.prev"; fi; trap restore_dest EXIT; }
restore_dest() { if [ -d "$DEST.prev" ]; then rm -rf "$DEST"; mv "$DEST.prev" "$DEST"; say "previous greeter files restored"; fi; }

sync_user_files() {
    GUSER="$(greeter_user)" || die "no greeter account (greeter/_greetd/greetd): install greetd first"
    install -d -m 755 "$DEST" "$DEST/greeter"
    install -m 644 "$HERE/quickshell/shell.qml" "$DEST/greeter/shell.qml"
    install -m 644 "$HERE/hyprland.lua" "$DEST/hyprland.lua"
    if [ -f "$USER_HOME/.config/sleek-shell/appearance.json" ] && ucopy "$USER_HOME/.config/sleek-shell/appearance.json" "$DEST/appearance.json"; then :
    elif [ ! -f "$DEST/appearance.json" ] && [ -f "$HERE/appearance.json" ]; then install -m 644 "$HERE/appearance.json" "$DEST/appearance.json"; fi
    write_greeter_settings
    wp="$(runuser -u "$USER_NAME" -- cat -- "$USER_HOME/.local/state/awww-rice/last-wallpaper" 2>/dev/null || true)"
    if [ -n "$wp" ] && [ -f "$wp" ] && ucopy "$wp" "$DEST/wallpaper"; then :
    elif [ -f "$HERE/wallpaper" ]; then install -m 644 "$HERE/wallpaper" "$DEST/wallpaper"
    else cp -f /usr/share/hypr/wall0.png "$DEST/wallpaper" 2>/dev/null || true; fi
    if [ -f "$USER_HOME/.config/sleek-shell/avatar" ] && ucopy "$USER_HOME/.config/sleek-shell/avatar" "$DEST/avatar"; then
        echo "$USER_NAME" > "$DEST/avatar-user"; chmod 644 "$DEST/avatar-user"
    else
        rm -f "$DEST/avatar" "$DEST/avatar-user"
    fi
    if [ -f "$USER_HOME/.config/hypr/monitors.lua" ] && ucopy "$USER_HOME/.config/hypr/monitors.lua" "$DEST/monitors.lua"; then :
    else rm -f "$DEST/monitors.lua"; fi
    write_keyboard
    if [ -n "$ROOT" ]; then install -d -m 750 "$CACHE"; else install -d -m 750 -o "$GUSER" -g "$(id -gn "$GUSER")" "$CACHE"; fi
    say "greeter files synced to $DEST"
}

# Parse-check the greeter compositor config as the greeter account (no compositor is started).
verify_hypr() {
    local rt out
    rt="$(mktemp -d /tmp/sleek-greeter-verify.XXXXXX)"
    [ -n "$ROOT" ] || chown "$GUSER" "$rt"; chmod 700 "$rt"
    out="$(runuser -u "$GUSER" -- env -i PATH=/usr/local/bin:/usr/bin:/bin HOME="$rt" XDG_RUNTIME_DIR="$rt" \
        Hyprland --verify-config -c "$DEST/hyprland.lua" 2>&1 || true)"
    rm -rf "$rt"
    if ! grep -q 'config ok' <<<"$out"; then
        tail -n 20 <<<"$out" >&2
        restore_dest
        die "greeter Hyprland config failed verification (no greetd config written, nothing enabled)"
    fi
    rm -rf "$DEST.prev"
    say "greeter Hyprland config verified"
}

write_greetd_conf() {   # $1 file, $2 vt, $3 extra [terminal] lines, $4 header comment
    local tmp
    tmp="$(mktemp "$1.XXXXXX")"
    cat > "$tmp" <<EOF
# Sleek Shell greeter (written by sleek-shell install.sh, $TS). $4
[terminal]
vt = $2
$3
[default_session]
command = "$HYPR_CMD"
user = "$GUSER"
EOF
    chmod 644 "$tmp"
    mv -f "$tmp" "$1"
}

case "$MODE" in
install)
    need_user
    was_enabled=no; greetd_enabled && was_enabled=yes
    was_active=no; greetd_active && was_active=yes
    command -v quickshell >/dev/null && command -v Hyprland >/dev/null || die "quickshell and Hyprland must be installed first (nothing changed)"
    install_greetd
    if [ "$was_enabled" = no ] && greetd_enabled; then
        systemctl disable greetd.service
        say "the greetd package enabled greetd.service; disabled it again (use --enable when you are ready)"
    fi
    if [ "$was_active" = no ] && greetd_active; then
        warn "the greetd package started greetd.service. Not stopping it here (that could end a login on its VT)."
        warn "When nobody is logged in through it: sudo systemctl stop greetd && sudo systemctl start getty@tty1"
    fi
    install_font
    GUSER="$(greeter_user)" || die "the greetd package did not create a greeter account"
    snapshot_dest
    sync_user_files
    # Hyprland >= 0.53 shows a warning banner unless started through its start-hyprland watchdog
    if command -v start-hyprland >/dev/null; then HYPR_CMD="$(command -v start-hyprland) -- --config $DEST/hyprland.lua"
    else HYPR_CMD="$(command -v Hyprland) --config $DEST/hyprland.lua"; fi
    verify_hypr
    write_greetd_conf "$STAGED" 1 "" "Copied to $CONF by install.sh --enable."
    write_greetd_conf "$TESTCONF" 7 "switch = true" "Manual test on VT7 only: sudo $HERE/install.sh --test"
    if is_ours "$CONF"; then
        install -m 644 "$STAGED" "$CONF"; say "refreshed $CONF (already the Sleek Shell greeter config)"
    else
        say "$CONF left unchanged (it is replaced only by --enable)"
    fi
    others="$(other_dms)"
    [ -z "$others" ] || warn "other display manager(s) enabled or running: $(echo $others). --enable will refuse until you disable them yourself."
    say "installed. Your login is unchanged. Next:"
    echo "    1. test safely:   sudo $HERE/install.sh --test"
    echo "    2. enable:        sudo $HERE/install.sh --enable   (then reboot)"
    ;;
--sync)
    need_user
    [ -f "$DEST/hyprland.lua" ] || die "run install first"
    snapshot_dest
    sync_user_files
    verify_hypr ;;
--test)
    [ -f "$TESTCONF" ] || die "run install first"
    GREETD_BIN="$(command -v greetd)" || die "greetd is not installed"
    cat <<EOF
Safe test (greetd stays disabled; your current session is not touched):
  greetd must run as a system service, like greetd.service does. Do NOT run "sudo greetd ..." from a
  terminal or TTY: it then inherits your login session, pam_systemd does not create a session for the
  greeter, XDG_RUNTIME_DIR is never set and start-hyprland fails ("bad json", "XDG_RUNTIME_DIR is not set!").
  1. Run:   sudo systemd-run --unit=sleek-greeter-test --collect -p KeyringMode=shared -p IgnoreSIGPIPE=no -p SendSIGHUP=yes $GREETD_BIN --config $TESTCONF
     The greeter opens on VT7. Log in there (it starts a second session) or just look around.
  2. Ctrl+Alt+F<n> returns to your session's VT. Log out of the test session first, then stop the test greeter:
            sudo systemctl stop sleek-greeter-test
     Logs: journalctl -b -u sleek-greeter-test ; sudo cat $CACHE/greeter.log
In-session preview without greetd (mock login, nothing is authenticated):
  quickshell -p $HERE/quickshell
EOF
    ;;
--enable)
    [ -f "$DEST/greeter/shell.qml" ] && [ -f "$STAGED" ] || die "run install first"
    systemctl cat greetd.service >/dev/null 2>&1 || die "greetd.service not found: is greetd installed?"
    nauto="$( { systemd-analyze cat-config systemd/logind.conf 2>/dev/null || cat "$ROOT/etc/systemd/logind.conf" 2>/dev/null || true; } \
        | sed -n 's/^[[:space:]]*NAutoVTs[[:space:]]*=[[:space:]]*//p' | tail -n1 || true)"
    [ "${nauto:-6}" != 0 ] || die "logind NAutoVTs=0: no TTY fallback would exist; refusing to enable"
    if [ "$REPLACE" = 1 ]; then others="$(other_dms enabled)"; else others="$(other_dms)"; fi
    if [ -n "$others" ]; then
        die "another display manager is enabled$( [ "$REPLACE" = 1 ] || echo ' or running'): $(echo $others). Disable it yourself first (sudo systemctl disable <unit>) if you really want to switch; nothing changed"
    fi
    echo "This makes the Sleek Shell greeter the login screen from the next boot:"
    if [ -f "$CONF" ] && ! is_ours "$CONF"; then echo "  * $CONF is replaced by $STAGED (the current file is backed up next to it first)"
    else echo "  * $CONF is set to $STAGED (it is already the Sleek Shell config or missing, so there is nothing to back up)"; fi
    echo "  * greetd.service is enabled (not started now). Text login stays on Ctrl+Alt+F2..F6."
    echo "  * undo: sudo $HERE/uninstall.sh"
    if [ "$ASSUME_YES" != 1 ]; then
        [ -t 0 ] || die "confirmation needed: run it in a terminal, or add --yes"
        read -r -p "Type 'enable' to continue: " answer
        [ "$answer" = enable ] || die "not confirmed; nothing changed"
    fi
    prev=no; greetd_enabled && prev=yes
    if [ -f "$CONF" ] && ! is_ours "$CONF"; then cp -a "$CONF" "$CONF.pre-sleek-shell-$TS"; say "backed up $CONF -> $CONF.pre-sleek-shell-$TS"; fi
    install -m 644 "$STAGED" "$CONF"
    [ -f "$STATE" ] || { printf 'greetd_was_enabled=%s\n' "$prev" > "$STATE"; chmod 644 "$STATE"; }
    systemctl enable greetd.service
    say "greetd enabled for the next boot. NOT started now."
    greetd_active && say "greetd is running with its old config; the Sleek Shell greeter appears after a reboot"
    echo "    Recovery at any time: Ctrl+Alt+F2, log in, then: sudo $HERE/uninstall.sh && reboot"
    ;;
esac
