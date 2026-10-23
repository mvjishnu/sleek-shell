#!/usr/bin/env bash
# Static checks: shell/Lua/QML/Python/JSON syntax, shellcheck (if installed), Hyprland --verify-config.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO" || exit 1

mapfile -t SH < <(
    { ls install.sh uninstall.sh lib/*.sh greeter/*.sh tests/*.sh hypr/scripts/*.sh quickshell/scripts/*.sh 2>/dev/null
      grep -lE '^#!.*\b(ba)?sh\b' calc/sleek-calc 2>/dev/null; } | sort -u)
bash_n() { local f; for f in "${SH[@]}"; do bash -n "$f" || { echo "syntax error: $f"; return 1; }; done; }
check "bash -n (${#SH[@]} scripts)" bash_n

if command -v shellcheck >/dev/null; then
    check "shellcheck (errors only)" shellcheck -S error "${SH[@]}"
else
    skip "shellcheck" "not installed"
fi

LUAC="$(command -v luac || command -v luac5.4 || command -v luac54 || true)"
mapfile -t LUA < <(find hypr greeter -name '*.lua' | sort)
if [ -n "$LUAC" ]; then
    check "Lua syntax (${#LUA[@]} files)" "$LUAC" -p "${LUA[@]}"
else
    skip "Lua syntax" "luac not installed"
fi

QMLFORMAT="$(command -v qmlformat || command -v qmlformat6 || ls /usr/lib/qt6/bin/qmlformat /usr/lib64/qt6/bin/qmlformat 2>/dev/null | head -n1 || true)"
mapfile -t QML < <(find quickshell greeter -name '*.qml' | sort)
qml_parse() { local f; for f in "${QML[@]}"; do "$QMLFORMAT" "$f" >/dev/null 2>&1 || { echo "parse error: $f"; return 1; }; done; }
if [ -n "$QMLFORMAT" ]; then check "QML parses (${#QML[@]} files)" qml_parse
else skip "QML parse" "qmlformat (Qt 6 declarative tools) not installed"; fi

mapfile -t PY < <(find . -name '*.py' -not -path '*/__pycache__/*' | sort)
py_ok() { python3 - "${PY[@]}" <<'EOF'
import ast, sys
for f in sys.argv[1:]:
    ast.parse(open(f, encoding="utf-8").read(), f)
EOF
}
check "Python syntax (${#PY[@]} files)" py_ok

mapfile -t JSON < <(find defaults greeter quickshell -name '*.json' | sort)
json_ok() { local f; for f in "${JSON[@]}"; do python3 -m json.tool "$f" >/dev/null || { echo "bad json: $f"; return 1; }; done; }
check "JSON valid (${#JSON[@]} files)" json_ok

check "scripts are executable" sh -c '! find install.sh uninstall.sh greeter/*.sh hypr/scripts quickshell/scripts calc/sleek-calc tests/*.sh \
    -type f \( -name "*.sh" -o -name "*.py" -o -name sleek-calc \) ! -perm -u+x ! -name lib.sh -print | grep .'
check "no symlinks in the tree" sh -c '! find . -path ./.git -prune -o -type l -print | grep .'

if command -v Hyprland >/dev/null; then
    H="$(new_home)"; mkdir -p "$H/.config"; cp -a hypr "$H/.config/hypr"
    verify() { out="$(in_home "$H" XDG_RUNTIME_DIR="$H" Hyprland --verify-config -c "$1" 2>&1)"; grep -q 'config ok' <<<"$out" || { echo "$out"; return 1; }; }
    check "Hyprland --verify-config (desktop config)" verify "$H/.config/hypr/hyprland.lua"
    check "Hyprland --verify-config (greeter config)" verify "$REPO/greeter/hyprland.lua"
    echo 'this is not lua' > "$H/.config/hypr/user.lua"
    check "a broken user.lua is reported, not fatal" sh -c "out=\$(env -u XDG_CONFIG_HOME HOME='$H' XDG_RUNTIME_DIR='$H' Hyprland --verify-config -c '$H/.config/hypr/hyprland.lua' 2>&1); echo \"\$out\" | grep -q 'user.lua'"
else
    skip "Hyprland --verify-config" "Hyprland not installed"
fi

help_clean() {
    local s out
    for s in install.sh uninstall.sh greeter/install.sh greeter/uninstall.sh; do
        out="$(bash "$REPO/$s" --help 2>&1)" || { echo "$s --help failed"; return 1; }
        if grep -qE '^(set -|[A-Za-z_]+=|if |for |\}|#!)' <<<"$out"; then echo "$s --help leaks code:"; grep -E '^(set -|[A-Za-z_]+=|if |for |\}|#!)' <<<"$out"; return 1; fi
    done
}
check "--help output is clean (no script lines)" help_clean

finish
