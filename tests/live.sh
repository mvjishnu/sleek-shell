#!/usr/bin/env bash
# Read-only checks against the Sleek Shell session you are logged into (whatever is installed in
# ~/.config). Changes nothing. Skips when not run inside a Hyprland session with Sleek Shell running.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"; HY="$CFG/hypr"; T="$HY/scripts/hypr-tools.py"

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || ! pgrep -x quickshell >/dev/null; then
    skip "live session checks" "not inside a Hyprland session with quickshell running"
    finish; exit $?
fi

check "quickshell running (single instance)" sh -c "[ \$(pgrep -cx quickshell) = 1 ]"
check "notification server owned by quickshell" sh -c "busctl --user status org.freedesktop.Notifications | grep -q 'Comm=quickshell'"
check "no Hyprland config errors" sh -c "[ -z \"\$(hyprctl configerrors | tr -d '[:space:]')\" ] || hyprctl configerrors | grep -qx 'no errors'"
check "current shell generation logged no QML errors/warnings" python3 "$REPO/tests/logcheck.py"
check "IPC targets present (settings, theme, media)" sh -c "s=\$(quickshell ipc show); echo \"\$s\" | grep -q 'target settings' && echo \"\$s\" | grep -q 'target theme' && echo \"\$s\" | grep -q 'target media'"
check "theme state readable over IPC" sh -c "quickshell ipc call theme get | python3 -c 'import json,sys; json.load(sys.stdin)'"
check "app theme policy readable over IPC" sh -c "quickshell ipc call theme apps | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"scope\" in d and \"apps\" in d'"
check "preferences readable over IPC" sh -c "quickshell ipc call prefs get | python3 -c 'import json,sys; json.load(sys.stdin)'"
if [ -f "$T" ]; then
    check "built-in binds labelled, live, no conflicts" python3 -c "
import json,subprocess; d=json.loads(subprocess.check_output(['python3','$T','binds']))
b=[x for x in d['binds'] if x['kind']=='builtin']
assert d['ok'] and len(b)>=40 and not d['conflicts'], (len(b), d['conflicts'])
assert all(x['action']!='__lua' and x['label'] for x in b)
assert all(x['live'] for x in b if x['enabled'] and 'Leave shortcut' not in x['label'])"
    check "conflict detection (SUPER+T)" sh -c "python3 '$T' conflicts 'SUPER + T' | grep -q 'terminal'"
    check "validation rejects a missing command" sh -c "python3 '$T' validate '{\"id\":\"t\",\"keys\":\"SUPER + F11\",\"kind\":\"command\",\"value\":\"nonexistent-cmd-x\"}' | grep -q 'not found'"
    check "validation flags a destructive command" sh -c "python3 '$T' validate '{\"id\":\"t\",\"keys\":\"SUPER + F11\",\"kind\":\"command\",\"value\":\"rm -rf /tmp/x\"}' | grep -q 'destructive'"
else
    skip "keybind tool checks" "$T not installed (shell profile)"
fi
check "wallpaper daemon running" pgrep -x awww-daemon
check "clipboard watchers running (text + image)" sh -c "[ \$(pgrep -c -f '^wl-paste --type') = 2 ]"

finish
