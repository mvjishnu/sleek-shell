#!/usr/bin/env bash
# Distro / init / display-manager detection against fixture os-release files and fake system roots.
# This simulates other distributions; it does not prove that Sleek Shell runs on them.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
FX="$REPO/tests/fixtures/os-release"

detect() {   # detect FIXTURE -> "family support"
    SLEEK_OS_RELEASE="$1" SLEEK_SYS_ROOT="$TMPROOT/none" bash -c '. "$0/lib/distro.sh"; detect_distro; echo "$DISTRO_FAMILY $DISTRO_SUPPORT"' "$REPO"
}
expect() {   # expect FIXTURE "family support"
    local got; got="$(detect "$FX/$1")"
    if [ "$got" = "$2" ]; then pass "os-release $1 -> $2"; else fail "os-release $1 -> expected '$2', got '$got'"; fi
}
expect arch "arch supported"
expect cachyos "arch supported"
expect endeavouros "arch supported"
expect manjaro "arch supported"
expect fedora "fedora experimental"
expect nobara "fedora experimental"
expect ubuntu "debian experimental"
expect debian "debian experimental"
expect linuxmint "debian experimental"
expect pop "debian experimental"
expect opensuse-tumbleweed "suse experimental"
expect opensuse-leap "suse experimental"
expect nixos "unknown unsupported"
expect gentoo "unknown unsupported"
expect void "unknown unsupported"
expect alpine "unknown unsupported"
expect does-not-exist "unknown unsupported"

rm -f /tmp/sleek-pwned
detect "$FX/hostile" >/dev/null
check "os-release is parsed as data, never executed" test ! -e /tmp/sleek-pwned

check "PRETTY_NAME is unquoted" sh -c "SLEEK_OS_RELEASE='$FX/fedora' bash -c '. \"$REPO/lib/distro.sh\"; detect_distro; [ \"\$DISTRO_NAME\" = \"Fedora Linux 42 (Workstation Edition)\" ]'"

# fake system roots: init system, display manager, greetd config
R="$TMPROOT/root"
sysq() { SLEEK_SYS_ROOT="$R" bash -c '. "$0/lib/distro.sh"; '"$1" "$REPO"; }
mkdir -p "$R/etc/systemd/system"
check "no /run/systemd/system -> init other" test "$(sysq init_system)" = other
mkdir -p "$R/run/systemd/system"
check "/run/systemd/system -> init systemd" test "$(sysq init_system)" = systemd
check "no display-manager.service -> none" test "$(sysq display_manager)" = none
ln -s /usr/lib/systemd/system/sddm.service "$R/etc/systemd/system/display-manager.service"
check "display-manager.service -> sddm" test "$(sysq display_manager)" = sddm
ln -sfn /usr/lib/systemd/system/greetd.service "$R/etc/systemd/system/display-manager.service"
check "display-manager.service -> greetd" test "$(sysq display_manager)" = greetd
mkdir -p "$R/etc/greetd"; printf '[default_session]\ncommand = "agreety --cmd bash"\n' > "$R/etc/greetd/config.toml"
check "greetd with agreety -> not Sleek" test "$(sysq greetd_uses_sleek)" = no
printf '[default_session]\ncommand = "start-hyprland -- --config /etc/greetd/sleek-shell/hyprland.lua"\n' > "$R/etc/greetd/config.toml"
check "greetd with Sleek greeter -> Sleek" test "$(sysq greetd_uses_sleek)" = yes

# install hints per family
hint() { bash -c '. "$0/lib/deps.sh"; DEP_PKGS_CORE=(quickshell rofi rofi); install_hint "$1"' "$REPO" "$1"; }
check "hint arch uses pacman" test "$(hint arch)" = "sudo pacman -S --needed quickshell rofi"
check "hint fedora uses dnf" test "$(hint fedora)" = "sudo dnf install quickshell rofi"
check "hint debian uses apt" test "$(hint debian)" = "sudo apt install quickshell rofi"
check "hint suse uses zypper" test "$(hint suse)" = "sudo zypper install quickshell rofi"
check "hint unknown names packages only" sh -c "[ \"\$(bash -c '. \"$REPO/lib/deps.sh\"; DEP_PKGS_CORE=(x); install_hint unknown')\" = 'install with your package manager: x' ]"

vge() { bash -c '. "$0/lib/deps.sh"; version_ge "$1" "$2"' "$REPO" "$1" "$2"; }
check "version 0.56.2 >= 0.55" vge 0.56.2 0.55
check "version 0.55 >= 0.55" vge 0.55 0.55
check "version 0.10.0 >= 0.9" vge 0.10.0 0.9
check "version 0.41.2 < 0.55" sh -c "! bash -c '. \"$REPO/lib/deps.sh\"; version_ge 0.41.2 0.55'"

# install.sh --check reports the detected family for each fixture (read-only)
for f in fedora ubuntu opensuse-tumbleweed nixos; do
    H="$(new_home)"
    check "install.sh --check on $f fixture" sh -c "SLEEK_OS_RELEASE='$FX/$f' HOME='$H' '$REPO/install.sh' --check 2>&1 | grep -q 'family: $(detect "$FX/$f" | cut -d' ' -f1)'"
done

finish
