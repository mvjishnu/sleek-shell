#!/usr/bin/env bash
# Lua runtime tests: run Hyprland modules against a mocked `hl` table, plus Lua pitfall lints.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO" || exit 1

LUA="$(command -v lua || command -v lua5.5 || command -v lua5.4 || true)"
if [ -z "$LUA" ]; then skip "Lua runtime tests" "lua not installed"; finish; exit $?; fi

# A line that starts with "(" continues the previous expression in Lua: `f(x)\n(g or h)(y)` is parsed as
# `f(x)(g or h)(y)`. This is what broke workspaces.lua on monitor hotplug.
paren_lint() {
    local hits
    hits="$(awk 'FNR==1{c=0} /--\[\[/{c=1} c&&/\]\]/{c=0; next} !c && /^[[:space:]]*\(/ {print FILENAME":"FNR": "$0}' \
        $(find hypr greeter -name '*.lua' | sort))"
    [ -z "$hits" ] || { echo "lines starting with '(' (use a local or a leading ';'):"; echo "$hits"; return 1; }
}
check "no Lua line starts with '(' (ambiguous call)" paren_lint

for t in tests/lua/*_test.lua; do
    H="$(new_home)"
    check "lua: $(basename "$t" .lua)" sh -c "cd '$REPO/hypr' && env -u XDG_CONFIG_HOME -u XDG_DATA_HOME HOME='$H' XDG_STATE_HOME='$H/state' '$LUA' '$REPO/$t'"
done
finish
