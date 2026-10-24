# shellcheck shell=bash
# Privileged commands for install.sh. The installer itself never runs as root: it asks for the sudo
# password once, keeps the timestamp fresh while it works, and runs only the commands it lists in the
# summary through priv(). In a dry run priv() only prints.
#
# Test hook: SLEEK_SUDO names the sudo command (tests point it at a stub that records the arguments).

SUDO_CMD="${SLEEK_SUDO:-sudo}"
PRIV_KEEPALIVE_PID=""
PRIV_LOG=()

# priv_init: ask for the password once (sudo -v) and refresh it in the background until the installer exits
priv_init() {
    [ "$DRY" = 1 ] && return 0
    command -v "$SUDO_CMD" >/dev/null 2>&1 || die "sudo is not installed. As root: pacman -S sudo, then add your user to the wheel group (visudo)"
    if ! "$SUDO_CMD" -n true 2>/dev/null; then
        say "  Administrator rights are needed for packages, drivers and services."
        "$SUDO_CMD" -v || die "sudo failed: your user needs sudo rights (wheel group). Nothing was changed."
    fi
    ( while kill -0 "$$" 2>/dev/null; do "$SUDO_CMD" -n -v 2>/dev/null || exit 0; sleep 50; done ) </dev/null >/dev/null 2>&1 &
    PRIV_KEEPALIVE_PID=$!
}

priv_stop() {
    if [ -n "$PRIV_KEEPALIVE_PID" ]; then kill "$PRIV_KEEPALIVE_PID" 2>/dev/null || true; fi
    PRIV_KEEPALIVE_PID=""
    return 0
}

# priv CMD...: run CMD as root. Returns CMD's status (callers decide whether it is fatal).
priv() {
    PRIV_LOG+=("$*")
    if [ "$DRY" = 1 ]; then printf '  %swould run%s sudo %s\n' "$C_Y" "$C_0" "$*"; return 0; fi
    "$SUDO_CMD" -- "$@"
}

# priv_write DEST MODE: write stdin to DEST as root (atomic: temp file in the same directory, then rename)
priv_write() {
    local dest="$1" mode="$2" tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/sleek-priv.XXXXXX")" || die "cannot create a temp file"
    cat > "$tmp"
    if [ "$DRY" = 1 ]; then printf '  %swould write%s %s\n' "$C_Y" "$C_0" "$dest"; rm -f "$tmp"; return 0; fi
    priv install -D -m "$mode" -- "$tmp" "$dest"
    local rc=$?
    rm -f "$tmp"
    return $rc
}
