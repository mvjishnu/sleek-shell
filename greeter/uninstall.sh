#!/usr/bin/env bash
# Roll back the Sleek Shell greeter.
#   sudo ./uninstall.sh            restore the previous /etc/greetd/config.toml and disable greetd again
#                                  (unless greetd was already enabled before Sleek Shell's --enable)
#   sudo ./uninstall.sh --purge    also remove /etc/greetd/sleek-shell and the greeter cache
# Never starts or stops greetd, so it is safe to run from a session that greetd started; the change
# takes effect at the next boot. Does not remove the greetd package.
set -euo pipefail
ROOT="${SLEEK_TEST_ROOT:-}"   # fixture tests only (see install.sh)
if [ -n "$ROOT" ]; then
    case "$ROOT" in /tmp/?*) [ -d "$ROOT" ] || { echo "error: SLEEK_TEST_ROOT does not exist" >&2; exit 1; } ;;
        *) echo "error: SLEEK_TEST_ROOT must be a directory under /tmp" >&2; exit 1 ;; esac
fi
CONF=$ROOT/etc/greetd/config.toml
DEST=$ROOT/etc/greetd/sleek-shell
CACHE=$ROOT/var/cache/sleek-shell-greeter
STATE="$DEST/state"
TS=$(date +%Y%m%d-%H%M%S)

die() { echo "error: $*" >&2; exit 1; }
say() { echo "==> $*"; }

PURGE=0
[ $# -le 1 ] || die "usage: sudo $0 [--purge]"
case "${1:-}" in
    "") ;;
    --purge) PURGE=1 ;;
    -h|--help) sed -n '2,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "usage: sudo $0 [--purge]" ;;
esac
[ "$(id -u)" = 0 ] || [ -n "$ROOT" ] || die "run with sudo"

is_ours() { [ -f "$1" ] && grep -q -e 'sleek-shell' -e 'sleak-shell' -e 'sleakos' "$1"; }
greetd_enabled() { case "$(systemctl is-enabled greetd.service 2>/dev/null)" in enabled|enabled-runtime|alias) return 0 ;; esac; return 1; }
running() { systemctl is-active --quiet "$1" 2>/dev/null; }

if [ "$PURGE" = 1 ]; then
    if running greetd.service || running sleek-greeter-test.service; then
        die "greetd is running and needs $DEST for its next greeter. Nothing changed. Run it without --purge (or reboot first), then purge"
    fi
fi

# state is written by install.sh --enable; without it we do not know who enabled greetd
was_enabled=unknown
[ -f "$STATE" ] && was_enabled="$(sed -n 's/^greetd_was_enabled=//p' "$STATE")"
conf_ours=no; is_ours "$CONF" && conf_ours=yes
disable_greetd() {
    systemctl disable greetd.service
    disabled_now=1
    say "greetd disabled; the text login (getty@tty1) is used again from the next boot"
}
disabled_now=0
if greetd_enabled; then
    case "$was_enabled" in
        yes) say "greetd was enabled before Sleek Shell; leaving it enabled with your previous config" ;;
        no) disable_greetd ;;
        *)  if [ "$conf_ours" = yes ]; then
                say "no record of greetd's state before Sleek Shell, and greetd is set to start the Sleek Shell greeter"
                disable_greetd
                say "if you used greetd with another greeter before, re-enable it: sudo systemctl enable greetd"
            else
                say "greetd is enabled with a config that is not Sleek Shell's and no record says Sleek Shell enabled it; left enabled"
            fi ;;
    esac
fi

# newest backup by the timestamp in its name (cp -a keeps the original file's mtime, so ls -t is not reliable);
# a backup that is itself a Sleek Shell config is never restored
last="$(for f in "$CONF".pre-sleek-shell-* "$CONF".pre-sleak-shell-* "$CONF".pre-sleakos-*; do
    if [ -f "$f" ] && ! is_ours "$f"; then printf '%s\t%s\n' "${f: -15}" "$f"; fi; done | sort | tail -n1 | cut -f2)"
if [ -f "$CONF" ] && ! is_ours "$CONF"; then
    say "$CONF is not the Sleek Shell config (already restored, or changed by you); left unchanged"
elif [ -n "$last" ]; then
    [ -f "$CONF" ] && cp -a "$CONF" "$CONF.sleek-shell-removed-$TS"
    cp -a "$last" "$CONF"
    say "restored $last -> $CONF"
elif [ -f "$CONF" ]; then
    if greetd_enabled; then
        say "no backup of a previous $CONF found; left the Sleek Shell config in place because greetd is still enabled"
    else
        mv "$CONF" "$CONF.sleek-shell-removed-$TS"
        say "no backup of a previous $CONF found; moved the Sleek Shell config to $CONF.sleek-shell-removed-$TS"
    fi
fi

rm -f "$ROOT/etc/greetd/sleek-shell.toml" "$ROOT/etc/greetd/sleek-shell-test.toml" "$STATE"
running sleek-greeter-test.service && say "the test greeter is still running: log out of its session, then: sudo systemctl stop sleek-greeter-test"
if [ "$PURGE" = 1 ]; then
    rm -rf "$DEST" "$DEST.prev" "$CACHE"
    say "removed $DEST and $CACHE"
fi
if [ "$disabled_now" = 1 ]; then say "done. Reboot to return to the text login on tty1."
else say "done."; fi
