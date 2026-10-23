#!/usr/bin/env bash
# Dependency checks and --install-deps with stub package managers: the right packages per family,
# confirmation is mandatory, third-party repositories and display managers are never installed.
# Nothing is installed: sudo, pacman, dnf, apt and zypper are stubs that only record their arguments.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FX="$REPO/tests/fixtures/os-release"
LOG="$TMPROOT/pm.log"
STUBS="$TMPROOT/stubs"; mkdir -p "$STUBS"
for c in sudo pacman dnf apt apt-get zypper; do
    printf '#!/bin/sh\necho "%s $*" >> "%s"\n' "$c" "$LOG" > "$STUBS/$c"; chmod +x "$STUBS/$c"
done
YESF="$TMPROOT/yes"; echo y > "$YESF"
NOF="$TMPROOT/no"; echo n > "$NOF"
NOTTY="$TMPROOT/no-such-tty"

TABLE='a|cmd:sleek-none-a|required|pa|pa (COPR x/y)|-|pa|a
b|cmd:sleek-none-b|recommended|pb|pb|pb|pb|b
c|cmd:sleek-none-c|optional|pc|pc|pc|pc|c
d|cmd:sh|required|pd|pd|pd|pd|present
e|cmd:sleek-none-e|recommended|greetd|sddm|lightdm|gdm|display manager
f|cmd:sleek-none-f|recommended|f1 f2|f1|f1|f1|two packages'

# deps FAMILY CODE: source the libs with the test table, run check_deps FAMILY, then CODE
deps() {
    SLEEK_SYS_ROOT="$TMPROOT/sys" PATH="$STUBS:$PATH" T="$TABLE" bash -c '
        . "$0/lib/common.sh"; . "$0/lib/distro.sh"; . "$0/lib/deps.sh"; DEPS_TABLE="$T"
        check_deps "$1" >/dev/null 2>&1; eval "$2"' "$REPO" "$1" "$2"
}
mkdir -p "$TMPROOT/sys"

check "arch core packages" test "$(deps arch 'echo ${DEP_PKGS_CORE[*]}')" = "pa pb f1 f2"
check "arch optional packages" test "$(deps arch 'echo ${DEP_PKGS_OPTIONAL[*]}')" = "pc"
queued() { deps "$1" 'echo ${DEP_PKGS_CORE[*]} ${DEP_PKGS_OPTIONAL[*]}'; }
manual() { deps "$1" 'printf "%s\n" "${DEP_MANUAL[@]}"'; }
unpackaged() { deps "$1" 'printf "%s\n" "${DEP_UNPACKAGED[@]}"'; }
check "display manager is never queued" sh -c "! grep -qwE 'greetd|sddm|lightdm|gdm' <<EOT
$(queued arch; queued fedora; queued debian; queued suse)
EOT"
check "display manager listed as manual" grep -q '^e|greetd|a display manager' <<<"$(manual arch)"
check "fedora: COPR package is not queued" test "$(deps fedora 'echo ${DEP_PKGS_CORE[*]}')" = "pb f1"
check "fedora: COPR package is listed as manual" grep -qx 'a|pa|COPR x/y' <<<"$(manual fedora)"
check "debian: unpackaged required dep is reported" grep -qx 'a|required' <<<"$(unpackaged debian)"
check "check_deps fails when a required dep is missing" test "$(deps arch 'check_deps arch >/dev/null 2>&1; echo $?')" = 1

# install_deps FAMILY OPTIONAL with prompt input $2 and DRY $3
inst() {
    : > "$LOG"
    SLEEK_PROMPT_IN="$2" DRY_RUN="${3:-0}" OPT="${4:-0}" SLEEK_SYS_ROOT="$TMPROOT/sys" PATH="$STUBS:$PATH" T="$TABLE" bash -c '
        . "$0/lib/common.sh"; . "$0/lib/distro.sh"; . "$0/lib/deps.sh"; DEPS_TABLE="$T"; DRY="$DRY_RUN"
        check_deps "$1" >/dev/null 2>&1; install_deps "$1" "$OPT"' "$REPO" "$1" >"$TMPROOT/inst.out" 2>&1
}
inst arch "$YESF"; rc=$?
check "confirmed: runs sudo pacman -S --needed with core packages" sh -c "[ $rc = 0 ] && [ \"\$(cat '$LOG')\" = 'sudo pacman -S --needed pa pb f1 f2' ]"
check "no --noconfirm / -y is passed" sh -c "! grep -qE -- '--noconfirm|(^| )-y( |$)|--yes|--assumeyes' '$LOG'"
inst arch "$YESF" 0 1
check "--with-optional adds optional packages" test "$(cat "$LOG")" = "sudo pacman -S --needed pa pb f1 f2 pc"
inst arch "$NOF"; rc=$?
check "declined: nothing runs" sh -c "[ $rc != 0 ] && [ ! -s '$LOG' ] && grep -q 'nothing was installed' '$TMPROOT/inst.out'"
inst arch "$NOTTY"; rc=$?
check "no terminal: nothing runs" sh -c "[ $rc != 0 ] && [ ! -s '$LOG' ]"
inst arch "$YESF" 1
check "dry run: prints the command, runs nothing" sh -c "[ ! -s '$LOG' ] && grep -q 'command: sudo pacman -S --needed pa pb f1 f2' '$TMPROOT/inst.out'"
for fam in fedora:"dnf install pb f1" debian:"apt install pb f1" suse:"zypper install pa pb f1"; do
    inst "${fam%%:*}" "$YESF"
    check "${fam%%:*}: sudo ${fam#*:}" test "$(cat "$LOG")" = "sudo ${fam#*:}"
done
inst unknown "$YESF"; rc=$?
check "unknown family: nothing runs" sh -c "[ $rc != 0 ] && [ ! -s '$LOG' ]"
: > "$LOG"
check "display manager in the list is refused" sh -c "! SLEEK_PROMPT_IN='$YESF' PATH='$STUBS:$PATH' bash -c '. \"$REPO/lib/common.sh\"; . \"$REPO/lib/deps.sh\"; DEP_PKGS_CORE=(rofi sddm); install_deps arch 0' >/dev/null 2>&1 && [ ! -s '$LOG' ]"

# real table: Arch names are plain, non-Arch third-party packages are annotated
real_pkgs() { awk -F'|' -v col="$1" 'NF>=8 && !/^#/{sub(/^DEPS_TABLE=./,"",$1); print $col}' "$REPO/lib/deps.sh"; }
check "every Arch cell is a plain package name" sh -c "! awk -F'|' 'NF>=8 && !/^#/ && \$4 ~ /[(]/' '$REPO/lib/deps.sh' | grep -q ."
check "no display manager in the dependency table" sh -c "! awk -F'|' 'NF>=8 && !/^#/{print \$4,\$5,\$6,\$7}' '$REPO/lib/deps.sh' | tr ' ' '\n' | grep -qxE 'greetd|sddm|gdm|gdm3|lightdm|ly'"
check "solopasha COPR is gone" sh -c "! grep -q solopasha '$REPO/lib/deps.sh'"

# check kinds against a fake system root and home
R="$TMPROOT/root"; H="$(new_home)"
mkdir -p "$R/usr/share/xdg-desktop-portal/portals" "$R/usr/share/icons/Adwaita/cursors" "$H/.icons/Papirus-Dark" \
         "$R/usr/lib/x86_64-linux-gnu/qt6/plugins/imageformats" "$R/usr/lib/x86_64-linux-gnu/libexec"
touch "$R/usr/share/xdg-desktop-portal/portals/hyprland.portal" "$H/.icons/Papirus-Dark/index.theme" \
      "$R/usr/lib/x86_64-linux-gnu/qt6/plugins/imageformats/libqwebp.so"
has() { env -u XDG_DATA_HOME HOME="$H" XDG_DATA_DIRS=/usr/share SLEEK_SYS_ROOT="$R" bash -c '. "$0/lib/distro.sh"; . "$0/lib/deps.sh"; _dep_has "$1"' "$REPO" "$1"; }
hasnt() { ! has "$1"; }
check "portal: found" has portal:hyprland
check "portal: missing gtk" hasnt portal:gtk
check "icon theme in ~/.icons" has icon:Papirus-Dark
check "cursor theme under XDG_DATA_DIRS" has cursor:Adwaita
check "icon theme without index.theme is missing" hasnt icon:Adwaita
check "qt plugin in a multiarch dir" has qtplugin:imageformats/libqwebp.so
check "polkit: none installed" hasnt polkit:agent
printf '#!/bin/sh\n' > "$R/usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1"; chmod +x "$R/usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1"
check "polkit: Debian multiarch polkit-kde found" has polkit:agent
mkdir -p "$R/usr/lib/hyprpolkitagent"; printf '#!/bin/sh\n' > "$R/usr/lib/hyprpolkitagent/hyprpolkitagent"; chmod +x "$R/usr/lib/hyprpolkitagent/hyprpolkitagent"
check "polkit-agent.sh prefers hyprpolkitagent" test "$(SLEEK_SYS_ROOT="$R" "$REPO/hypr/scripts/polkit-agent.sh" --find)" = "$R/usr/lib/hyprpolkitagent/hyprpolkitagent"
check "polkit-agent.sh --find with no agent fails" sh -c "! SLEEK_SYS_ROOT='$TMPROOT/sys' '$REPO/hypr/scripts/polkit-agent.sh' --find"
check "autostart runs polkit-agent.sh" grep -q 'polkit-agent.sh' "$REPO/hypr/modules/autostart.lua"

# service hints only print commands
if [ -d /run/systemd/system ]; then
    SVC="$TMPROOT/svc"; mkdir -p "$SVC"
    printf '#!/bin/sh\necho "systemctl $*" >> "%s"\ncase "$*" in *is-active*) exit 3 ;; esac\nexit 0\n' "$LOG" > "$SVC/systemctl"
    printf '#!/bin/sh\nexit 0\n' > "$SVC/nmcli"; chmod +x "$SVC/systemctl" "$SVC/nmcli"
    : > "$LOG"
    out="$(PATH="$SVC:$PATH" bash -c '. "$0/lib/common.sh"; . "$0/lib/distro.sh"; . "$0/lib/deps.sh"; service_hints' "$REPO" 2>&1)"
    check "service hint names the enable command" grep -q 'sudo systemctl enable --now NetworkManager.service' <<<"$out"
    check "service hints never start or enable" sh -c "! grep -qE 'systemctl( --user)? (start|enable|restart)' '$LOG'"
else
    skip "service hints" "no systemd"
fi

# install.sh end to end with every dependency missing (stub package manager)
MIN="$TMPROOT/minbin"; mkdir -p "$MIN"
for c in bash sh env id date cat sed awk grep sort cut tr head tail mkdir dirname basename readlink printf \
         uname sha256sum find mktemp rm cp mv chmod install ln stat wc ls; do
    p="$(command -v "$c")" && ln -sf "$p" "$MIN/$c"
done
cp "$STUBS"/* "$MIN/"
H="$(new_home)"
run_inst() { : > "$LOG"; in_home "$H" env PATH="$MIN" SLEEK_OS_RELEASE="$FX/$1" SLEEK_PROMPT_IN="$2" "$REPO/install.sh" "${@:3}" >"$TMPROOT/e2e.log" 2>&1; }
run_inst arch "$YESF" --check --install-deps; rc=$?
check "e2e arch: confirmed install runs pacman once" sh -c "[ \$(wc -l < '$LOG') = 1 ] && grep -q '^sudo pacman -S --needed hyprland quickshell ' '$LOG'"
check "e2e arch: re-checks and still exits 3 (stub installed nothing)" sh -c "[ $rc = 3 ] && grep -q 'Dependencies after installing' '$TMPROOT/e2e.log'"
check "e2e arch: no display manager, no optional packages" sh -c "! grep -qE ' (greetd|sddm|gdm|lightdm|ly|playerctl|blueman)( |$)' '$LOG'"
check "e2e: home untouched by --check --install-deps" test -z "$(ls -A "$H")"
run_inst arch "$NOTTY" --check --install-deps --yes
check "e2e: --yes does not answer the package prompt" sh -c "[ ! -s '$LOG' ] && grep -q 'no terminal to confirm' '$TMPROOT/e2e.log'"
run_inst fedora "$YESF" --check --install-deps
check "e2e fedora: hyprland not queued, COPR named" sh -c "! grep -q ' hyprland ' '$LOG' && grep -q 'COPR sdegler/hyprland' '$TMPROOT/e2e.log' && grep -q '^sudo dnf install ' '$LOG'"
run_inst debian "$YESF" --check --install-deps
check "e2e debian: nerd font reported as unpackaged" grep -q 'nerd-font (required): not packaged for debian' "$TMPROOT/e2e.log"
run_inst arch "$YESF" --check --install-deps --dry-run
check "e2e dry run: nothing runs" test ! -s "$LOG"
run_inst arch "$YESF" --check
check "e2e: --check alone never runs the package manager" test ! -s "$LOG"

finish
