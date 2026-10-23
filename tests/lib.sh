# shellcheck shell=bash
# Shared helpers for the test scripts. Every test works in a throwaway directory under /tmp and never
# touches your real home, /etc or running services.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0 FAIL=0 SKIP=0
TESTS_NAME="$(basename "$0" .sh)"
TMPROOT="$(mktemp -d /tmp/sleek-test-"$TESTS_NAME".XXXXXX)"
[ -n "${SLEEK_KEEP_TMP:-}" ] || trap 'rm -rf "$TMPROOT"' EXIT

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
skip() { printf '  SKIP  %s (%s)\n' "$1" "$2"; SKIP=$((SKIP + 1)); }

# check NAME CMD... : pass when CMD exits 0; on failure show the last lines of its output
check() {
    local name="$1" out; shift
    if out="$("$@" 2>&1)"; then pass "$name"
    else fail "$name"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        | /'; fi
}

# a fresh HOME with no XDG overrides; prints its path
new_home() {
    local h; h="$(mktemp -d "$TMPROOT/home.XXXXXX")"
    printf '%s\n' "$h"
}

# in_home HOME CMD... : run CMD with HOME set and the XDG base dirs cleared. SLEEK_SYS_ROOT points at an
# empty system root so the real /etc (e.g. an installed greeter) does not change the result.
in_home() {
    local h="$1"; shift
    mkdir -p "$TMPROOT/sys"
    env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME -u HYPRLAND_INSTANCE_SIGNATURE \
        HOME="$h" SLEEK_SYS_ROOT="${SYS:-$TMPROOT/sys}" "$@"
}

finish() {
    printf '== %s: %d passed, %d failed, %d skipped\n' "$TESTS_NAME" "$PASS" "$FAIL" "$SKIP"
    [ "$FAIL" = 0 ]
}
