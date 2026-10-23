#!/usr/bin/env bash
# greeter/install.sh and greeter/uninstall.sh against a fake system root (SLEEK_TEST_ROOT under /tmp)
# with stubbed systemctl/runuser/getent/id/localectl/fc-list. No root, nothing outside /tmp is changed,
# and no service is touched. The real Hyprland is used for --verify-config when installed.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
G="$REPO/greeter"
R="$TMPROOT/root"; FH="$TMPROOT/fakehome"; BIN="$TMPROOT/bin"
mkdir -p "$R/etc/greetd" "$R/etc/systemd/system" "$R/var/cache" "$R/.sd" "$BIN" "$FH/.config/sleek-shell" "$FH/.config/hypr"

stub() { printf '#!/bin/bash\n%s\n' "$2" > "$BIN/$1"; chmod +x "$BIN/$1"; }
stub systemctl 'S='"$R"'/.sd
case "$1" in
  is-enabled) cat "$S/${2%.service}.enabled" 2>/dev/null || { echo disabled; exit 1; } ;;
  is-active) [ "$2" = --quiet ] && shift; [ -e "$S/${2%.service}.active" ] ;;
  enable) echo enabled > "$S/${2%.service}.enabled" ;;
  disable) rm -f "$S/${2%.service}.enabled" ;;
  list-units) shift 4; for u in "$@"; do [ -e "$S/${u%.service}.active" ] && echo "$u loaded active running"; done; true ;;
  cat) exit 0 ;;
  *) echo "unexpected systemctl $*" >&2; exit 1 ;;
esac'
stub runuser 'while [ "$1" != -- ]; do shift; done; shift; exec "$@"'
stub getent '[ "$1" = passwd ] && echo "$2:x:1000:1000::'"$FH"':/bin/bash"'
stub id 'case "$1" in greeter) exit 0 ;; _greetd|greetd) exit 1 ;; -gn) echo greeter ;; *) exec /usr/bin/id "$@" ;; esac'
stub localectl 'printf "   System Locale: LANG=en_US.UTF-8\n       X11 Layout: de\n      X11 Variant: nodeadkeys\n"'
stub fc-list 'echo "/usr/share/fonts/inter/Inter.ttc: Inter"'
stub greetd 'exit 0'
stub systemd-analyze 'cat "'"$R"'/etc/systemd/logind.conf" 2>/dev/null; true'
command -v quickshell >/dev/null || stub quickshell 'exit 0'

printf '{ "palette": "rose", "glass": 0.5 }\n' > "$FH/.config/sleek-shell/appearance.json"
printf '{ "clock24h": true, "weatherCity": "Secret Town", "apiKey": "abc123" }\n' > "$FH/.config/sleek-shell/settings.json"
printf 'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })\n' > "$FH/.config/hypr/monitors.lua"
AGREETY='[terminal]
vt = 1
[default_session]
command = "agreety --cmd /bin/sh"
user = "greeter"'
printf '%s\n' "$AGREETY" > "$R/etc/greetd/config.toml"

gi() { env PATH="$BIN:$PATH" SUDO_USER=tester SLEEK_TEST_ROOT="$R" bash "$G/install.sh" "$@"; }
gu() { env PATH="$BIN:$PATH" SLEEK_TEST_ROOT="$R" bash "$G/uninstall.sh" "$@"; }
D="$R/etc/greetd/sleek-shell"

check "test root outside /tmp is refused" sh -c "! SLEEK_TEST_ROOT='$HOME' bash '$G/install.sh' >/dev/null 2>&1 && ! SLEEK_TEST_ROOT='$HOME' bash '$G/uninstall.sh' >/dev/null 2>&1"
check "unknown option is refused" sh -c "! env PATH='$BIN:$PATH' SLEEK_TEST_ROOT='$R' bash '$G/install.sh' --bogus >/dev/null 2>&1"
check "--enable before install is refused" sh -c "! env PATH='$BIN:$PATH' SUDO_USER=tester SLEEK_TEST_ROOT='$R' bash '$G/install.sh' --enable --yes >/dev/null 2>&1"

if ! command -v Hyprland >/dev/null; then
    skip "greeter install / enable / uninstall" "Hyprland not installed (needed for --verify-config)"
    finish; exit $?
fi

check "install" gi
check "greeter files installed" sh -c "test -f '$D/greeter/shell.qml' -a -f '$D/hyprland.lua' -a -f '$R/etc/greetd/sleek-shell.toml' -a -f '$R/etc/greetd/sleek-shell-test.toml'"
check "install leaves the existing login config alone" test "$(cat "$R/etc/greetd/config.toml")" = "$AGREETY"
check "install does not enable greetd" test ! -e "$R/.sd/greetd.enabled"
check "your appearance is copied" grep -q rose "$D/appearance.json"
check "only clock24h is copied from settings.json" test "$(cat "$D/settings.json")" = '{ "clock24h": true }'
check "keyboard layout from localectl" sh -c "grep -q 'kb_layout = \"de\"' '$D/keyboard.lua' && grep -q 'kb_variant = \"nodeadkeys\"' '$D/keyboard.lua'"
check "monitor layout copied" test -f "$D/monitors.lua"
check "greetd config runs the greeter compositor config" grep -q "config $D/hyprland.lua" "$R/etc/greetd/sleek-shell.toml"
check "test config uses VT7" grep -qx 'vt = 7' "$R/etc/greetd/sleek-shell-test.toml"

ln -sf /etc/shadow "$FH/.config/sleek-shell/appearance.json"
check "a symlink to an unreadable file is not copied" sh -c "env PATH='$BIN:$PATH' SUDO_USER=tester SLEEK_TEST_ROOT='$R' bash '$G/install.sh' --sync >/dev/null 2>&1; grep -q rose '$D/appearance.json'"
rm -f "$FH/.config/sleek-shell/appearance.json"; printf '{ "palette": "rose" }\n' > "$FH/.config/sleek-shell/appearance.json"

G2="$TMPROOT/greeter-broken"; cp -a "$G" "$G2"; echo 'this is not lua (' >> "$G2/hyprland.lua"
cp "$D/hyprland.lua" "$TMPROOT/good.lua"
check "a config that fails verification is rolled back" sh -c "! env PATH='$BIN:$PATH' SUDO_USER=tester SLEEK_TEST_ROOT='$R' bash '$G2/install.sh' --sync >/dev/null 2>&1 && cmp -s '$TMPROOT/good.lua' '$D/hyprland.lua' && [ ! -e '$D.prev' ]"

ln -s /usr/lib/systemd/system/sddm.service "$R/etc/systemd/system/display-manager.service"
check "--enable refuses while another display manager is enabled" sh -c "! env PATH='$BIN:$PATH' SUDO_USER=tester SLEEK_TEST_ROOT='$R' bash '$G/install.sh' --enable --yes >/dev/null 2>&1 && [ ! -e '$R/.sd/greetd.enabled' ]"
rm "$R/etc/systemd/system/display-manager.service"
mkdir -p "$R/etc/systemd/system/graphical.target.wants"; ln -s /usr/lib/systemd/system/lightdm.service "$R/etc/systemd/system/graphical.target.wants/lightdm.service"; touch "$R/usr-lightdm"
ln -sf "$R/usr-lightdm" "$R/etc/systemd/system/graphical.target.wants/lightdm.service"
check "--enable refuses while another display manager is wanted" sh -c "! env PATH='$BIN:$PATH' SUDO_USER=tester SLEEK_TEST_ROOT='$R' bash '$G/install.sh' --enable --yes >/dev/null 2>&1 && [ ! -e '$R/.sd/greetd.enabled' ]"
rm -r "$R/etc/systemd/system/graphical.target.wants"
touch "$R/.sd/sddm.active"
check "--enable refuses while another display manager is running" sh -c "! env PATH='$BIN:$PATH' SUDO_USER=tester SLEEK_TEST_ROOT='$R' bash '$G/install.sh' --enable --yes >/dev/null 2>&1 && [ ! -e '$R/.sd/greetd.enabled' ]"
rm "$R/.sd/sddm.active"
mkdir -p "$R/etc/systemd"; printf '[Login]\nNAutoVTs=0\n' > "$R/etc/systemd/logind.conf"
check "--enable refuses with no TTY fallback (NAutoVTs=0)" sh -c "! env PATH='$BIN:$PATH' SUDO_USER=tester SLEEK_TEST_ROOT='$R' bash '$G/install.sh' --enable --yes >/dev/null 2>&1 && [ ! -e '$R/.sd/greetd.enabled' ]"
rm "$R/etc/systemd/logind.conf"
check "--enable needs a terminal or --yes" sh -c "! env PATH='$BIN:$PATH' SUDO_USER=tester SLEEK_TEST_ROOT='$R' bash '$G/install.sh' --enable </dev/null >/dev/null 2>&1 && [ ! -e '$R/.sd/greetd.enabled' ]"
check "config.toml still untouched after refusals" test "$(cat "$R/etc/greetd/config.toml")" = "$AGREETY"

check "--enable --yes" gi --enable --yes
check "--enable backs up the previous config.toml" sh -c "ls '$R'/etc/greetd/config.toml.pre-sleek-shell-* && grep -q agreety '$R'/etc/greetd/config.toml.pre-sleek-shell-*"
check "--enable switches config.toml and enables greetd" sh -c "grep -q sleek-shell '$R/etc/greetd/config.toml' && [ -e '$R/.sd/greetd.enabled' ] && grep -qx greetd_was_enabled=no '$D/state'"
check "install again refreshes the active Sleek config" sh -c "env PATH='$BIN:$PATH' SUDO_USER=tester SLEEK_TEST_ROOT='$R' bash '$G/install.sh' 2>&1 | grep -q 'refreshed'"

touch "$R/.sd/greetd.active"
check "uninstall --purge refuses while greetd is running" sh -c "! env PATH='$BIN:$PATH' SLEEK_TEST_ROOT='$R' bash '$G/uninstall.sh' --purge >/dev/null 2>&1 && [ -d '$D' ] && grep -q sleek-shell '$R/etc/greetd/config.toml'"
check "uninstall (greetd running: allowed, takes effect at boot)" gu
rm "$R/.sd/greetd.active"
check "uninstall restores the previous config.toml" test "$(cat "$R/etc/greetd/config.toml")" = "$AGREETY"
check "uninstall disables greetd (it was disabled before)" test ! -e "$R/.sd/greetd.enabled"
check "uninstall removes the staged configs" sh -c "[ ! -e '$R/etc/greetd/sleek-shell.toml' ] && [ ! -e '$R/etc/greetd/sleek-shell-test.toml' ] && [ ! -e '$D/state' ]"
check "uninstall --purge removes the greeter files" sh -c "env PATH='$BIN:$PATH' SLEEK_TEST_ROOT='$R' bash '$G/uninstall.sh' --purge >/dev/null && [ ! -e '$D' ] && [ ! -e '$R/var/cache/sleek-shell-greeter' ]"

# greetd was already enabled (with another greeter) before Sleek Shell: uninstall leaves it enabled
echo enabled > "$R/.sd/greetd.enabled"
gi >/dev/null 2>&1; gi --enable --yes >/dev/null 2>&1
check "greetd enabled before: state records it" grep -qx greetd_was_enabled=yes "$D/state"
gu >/dev/null 2>&1
check "greetd enabled before: uninstall keeps it enabled with the old config" sh -c "[ -e '$R/.sd/greetd.enabled' ] && grep -q agreety '$R/etc/greetd/config.toml'"

finish
