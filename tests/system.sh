#!/usr/bin/env bash
# The system phase of install.sh end to end on a fake Arch system: packages, AUR, NVIDIA, services,
# login screen, login shell, browser, idle, verification and the report.
#
# Nothing touches the real system. sudo, pacman, pacman-conf, systemctl, getent, git, makepkg, yay and
# every program a package would install are stubs that work on a fixture root ($SYS_ROOT) and a state
# directory. install.sh runs with an empty environment and a minimal PATH that has no real sudo, inside a
# bubblewrap sandbox with a read-only / when bwrap works. Any privileged call the stubs do not expect is
# logged as UNEXPECTED and fails.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "$(id -u)" != 0 ] || { skip "system suite" "runs as a normal user (install.sh refuses root)"; finish; exit; }
PY3="$(command -v python3)" || { skip "system suite" "python3 missing"; finish; exit; }
STUBSRC="$TMPROOT/stubsrc"; mkdir -p "$STUBSRC"

# ---------------------------------------------------------------- package universe
# REPOS: every package the fake repositories have. AUR-only packages are left out on purpose.
REPOS="$TMPROOT/repos"
bash -c '
    DRY=0; . "$0/lib/common.sh"; . "$0/lib/distro.sh"; . "$0/lib/deps.sh"; . "$0/lib/priv.sh"; . "$0/lib/gpu.sh"; . "$0/lib/arch.sh"
    printf "%s\n" "${ARCH_BASE_PKGS[@]}"
    awk -F"|" "NF>=8{print \$4}" <<<"$DEPS_TABLE" | tr " " "\n"
    printf "%s\n" mesa vulkan-radeon vulkan-intel intel-media-driver vulkan-nouveau nvidia-open nvidia-open-lts \
        nvidia-open-dkms nvidia-utils libva-nvidia-driver nvidia-prime linux-headers linux-lts-headers \
        firefox chromium vivaldi epiphany base-devel git archlinux-keyring greetd pulseaudio tuned
' "$REPO" | grep -v '^$' | sort -u > "$REPOS"

# PROVIDES: "package kind:what" lines. Installing a package creates what it provides.
PROVIDES="$TMPROOT/provides"
{
    awk -F'|' 'NF>=8 && $2 ~ /^cmd:/ { split($4, p, " "); n = split(substr($2, 5), c, "/"); for (i = 1; i <= n; i++) print p[1], "cmd:" c[i] }' \
        < <(bash -c '. "$0/lib/deps.sh"; printf "%s\n" "$DEPS_TABLE"' "$REPO")
    cat <<'EOF'
hyprland cmd:hyprctl
fontconfig cmd:fc-list
xdg-utils cmd:xdg-mime
xdg-user-dirs cmd:xdg-user-dirs-update
zsh cmd:zsh
git cmd:git
base-devel cmd:makepkg
yay-bin cmd:yay
ttf-jetbrains-mono-nerd font:JetBrainsMono Nerd Font
inter-font font:Inter
noto-fonts font:Noto Sans
papirus-icon-theme file:usr/share/icons/Papirus-Dark/index.theme
adwaita-cursors file:usr/share/icons/Adwaita/cursors/default
xdg-desktop-portal-hyprland file:usr/share/xdg-desktop-portal/portals/hyprland.portal
xdg-desktop-portal-gtk file:usr/share/xdg-desktop-portal/portals/gtk.portal
hyprpolkitagent exe:usr/lib/hyprpolkitagent/hyprpolkitagent
qt6-imageformats file:usr/lib/qt6/plugins/imageformats/libqwebp.so
firefox file:usr/share/applications/firefox.desktop
chromium file:usr/share/applications/chromium.desktop
google-chrome file:usr/share/applications/google-chrome.desktop
greetd unit:greetd.service
networkmanager unit:NetworkManager.service
bluez unit:bluetooth.service
power-profiles-daemon unit:power-profiles-daemon.service
nvidia-utils unit:nvidia-suspend.service
nvidia-utils unit:nvidia-resume.service
nvidia-utils unit:nvidia-hibernate.service
nvidia-580xx-utils unit:nvidia-suspend.service
nvidia-580xx-utils unit:nvidia-resume.service
nvidia-580xx-utils unit:nvidia-hibernate.service
EOF
} > "$PROVIDES"

# Programs with behaviour; every other provided command is "exit 0". @STATE@ is filled in per scenario.
cat > "$STUBSRC/Hyprland" <<'EOF'
#!/bin/sh
case "$1" in --version) echo "Hyprland 0.56.2 built from branch" ;; --verify-config) echo "config ok" ;; esac
exit 0
EOF
printf '#!/bin/sh\necho "quickshell 0.2.1"\n' > "$STUBSRC/quickshell"
printf '#!/bin/sh\necho "Version: 2.0.0"\n' > "$STUBSRC/rofi"
printf '#!/bin/sh\ncat "@STATE@/fonts" 2>/dev/null\nexit 0\n' > "$STUBSRC/fc-list"
cat > "$STUBSRC/xdg-mime" <<'EOF'
#!/bin/sh
f="$HOME/.config/mimeapps.list"
case "$1" in
    query) [ -f "$f" ] && sed -n "s|^$3=||p" "$f" | head -n1; exit 0 ;;
    default) d="$2"; shift 2; mkdir -p "$HOME/.config"
        [ -f "$f" ] || echo '[Default Applications]' > "$f"
        for t in "$@"; do grep -v "^$t=" "$f" > "$f.tmp"; mv "$f.tmp" "$f"; echo "$t=$d" >> "$f"; done ;;
esac
EOF
printf '#!/bin/sh\nmkdir -p "$HOME/.config" && touch "$HOME/.config/user-dirs.dirs"\n' > "$STUBSRC/xdg-user-dirs-update"
cat > "$STUBSRC/git" <<'EOF'
#!/bin/sh
echo "git $*" >> "@STATE@/cmd.log"
[ "$1" = clone ] || exit 1
for d; do :; done; mkdir -p "$d" && touch "$d/PKGBUILD"
EOF
cat > "$STUBSRC/makepkg" <<'EOF'
#!/bin/sh
echo "makepkg $*" >> "@STATE@/cmd.log"
[ -f PKGBUILD ] || exit 1
. "@STATE@/lib.sh"; add_pkg yay-bin
EOF
cat > "$STUBSRC/yay" <<'EOF'
#!/bin/sh
echo "yay $*" >> "@STATE@/cmd.log"
[ -e "@STATE@/fail-yay" ] && { echo "error: build failed" >&2; exit 1; }
. "@STATE@/lib.sh"
for a; do case "$a" in -*|None) ;; *) add_pkg "$a" ;; esac; done
EOF

# ---------------------------------------------------------------- per-scenario fixture
# new_system NAME: a fake fresh Arch (bash login shell, linux kernel, systemd, nothing else). Sets SYS, ST
# (state), SB (stub bin), H (home). Tweak the fixture afterwards with the helpers below.
new_system() {
    SYS="$TMPROOT/$1/root" ST="$TMPROOT/$1/state" SB="$TMPROOT/$1/state/bin" H="$TMPROOT/$1/home"
    mkdir -p "$SYS/etc" "$SYS/run/systemd/system" "$SYS/usr/lib/modules/6.17.1-arch1-1" "$SYS/etc/systemd/system" \
             "$SYS/sys/bus/pci/devices" "$SYS/sys/class/power_supply" "$SB" "$H" "$TMPROOT/$1/tmp"
    cp "$REPO/tests/fixtures/os-release/arch" "$SYS/etc/os-release"
    echo linux > "$SYS/usr/lib/modules/6.17.1-arch1-1/pkgbase"
    printf '%s\n' base linux linux-firmware sudo bash coreutils mkinitcpio > "$ST/pkgs"
    : > "$ST/enabled"; : > "$ST/enabled-global"; : > "$ST/fonts"; : > "$ST/sudo.log"; : > "$ST/cmd.log"
    printf '%s\n' systemd-networkd.service dhcpcd.service iwd.service getty@.service > "$ST/units"
    echo /bin/bash > "$ST/shell"
    cat > "$ST/lib.sh" <<EOF
ST='$ST' SYS='$SYS' SB='$SB' STUBSRC='$STUBSRC'
add_pkg() {
    grep -qx "\$1" "\$ST/pkgs" || echo "\$1" >> "\$ST/pkgs"
    grep "^\$1 " '$PROVIDES' | while read -r _ what; do
        case "\$what" in
            cmd:python3) ln -sf '$PY3' "\$SB/python3" ;;
            cmd:*) c="\${what#cmd:}"
                if [ -f "\$STUBSRC/\$c" ]; then sed "s|@STATE@|\$ST|g" "\$STUBSRC/\$c" > "\$SB/\$c"; else printf '#!/bin/sh\nexit 0\n' > "\$SB/\$c"; fi
                chmod +x "\$SB/\$c" ;;
            font:*) echo "\${what#font:}" >> "\$ST/fonts" ;;
            file:*|exe:*) f="\$SYS/\${what#*:}"; mkdir -p "\${f%/*}"; touch "\$f"; case "\$what" in exe:*) chmod +x "\$f" ;; esac ;;
            unit:*) echo "\${what#unit:}" >> "\$ST/units" ;;
        esac
    done
}
EOF
    write_stubs
}

pci() {   # pci SLOT VENDOR DEVICE DRIVER
    local d="$SYS/sys/bus/pci/devices/$1"
    mkdir -p "$d" "$SYS/sys/bus/pci/drivers/$4"
    echo 0x030000 > "$d/class"; echo "0x$2" > "$d/vendor"; echo "0x$3" > "$d/device"
    ln -s "../../../bus/pci/drivers/$4" "$d/driver"
}
battery() { mkdir -p "$SYS/sys/class/power_supply/BAT0"; echo Battery > "$SYS/sys/class/power_supply/BAT0/type"; }
enable_unit() { echo "$1" >> "$ST/enabled"; grep -qx "$1" "$ST/units" || echo "$1" >> "$ST/units"; }
installed() { local p; for p; do echo "$p" >> "$ST/pkgs"; done; }
dm() { enable_unit "$1.service"; ln -sfn "/usr/lib/systemd/system/$1.service" "$SYS/etc/systemd/system/display-manager.service"; }

write_stubs() {
    # sudo: records every command, then runs it against the fixture
    cat > "$SB/sudo" <<EOF
#!/bin/bash
ST='$ST' SYS='$SYS'
case "\$*" in "-n true"|"-v") exit 0 ;; "-n -v") exit 1 ;; esac
[ "\$1" = -- ] && shift
echo "\$*" >> "\$ST/sudo.log"
export SLEEK_STUB_ROOT=1
case "\$1" in
    pacman|systemctl) exec "\$@" ;;
    install)
        [ "\$2 \$3 \$5" = "-D -m --" ] || { echo "UNEXPECTED \$*" >> "\$ST/sudo.log"; exit 1; }
        case "\$7" in /etc/*) ;; *) echo "UNEXPECTED \$*" >> "\$ST/sudo.log"; exit 1 ;; esac
        command install -D -m "\$4" "\$6" "\$SYS\$7" ;;
    usermod) [ "\$2" = -s ] && echo "\$3" > "\$ST/shell" ;;
    mkinitcpio) [ "\$2" = -P ] && touch "\$ST/initramfs" ;;
    bash)
        case "\$2" in */greeter/install.sh) ;; *) echo "UNEXPECTED \$*" >> "\$ST/sudo.log"; exit 1 ;; esac
        [ -e "\$ST/fail-greeter" ] && exit 1
        grep -qx greetd "\$ST/pkgs" || { echo "greetd not installed" >&2; exit 1; }
        case "\$3" in
            install) mkdir -p "\$SYS/etc/greetd/sleek-shell" ;;
            --enable)
                printf '[default_session]\ncommand = "start-hyprland -- -c /etc/greetd/sleek-shell/hyprland.lua"\n' > "\$SYS/etc/greetd/config.toml"
                echo greetd.service >> "\$ST/enabled"
                ln -sfn /usr/lib/systemd/system/greetd.service "\$SYS/etc/systemd/system/display-manager.service" ;;
            *) echo "UNEXPECTED \$*" >> "\$ST/sudo.log"; exit 1 ;;
        esac ;;
    *) echo "UNEXPECTED \$*" >> "\$ST/sudo.log"; exit 1 ;;
esac
EOF
    cat > "$SB/pacman" <<EOF
#!/bin/bash
. '$ST/lib.sh'
case "\$1" in
    -Qq) cat "\$ST/pkgs"; exit 0 ;;
    -Q) shift; rc=0; for p; do if grep -qx "\$p" "\$ST/pkgs"; then echo "\$p 1-1"; else echo "error: package '\$p' was not found" >&2; rc=1; fi; done; exit \$rc ;;
    -Slq) cat '$REPOS'; exit 0 ;;
esac
[ "\${SLEEK_STUB_ROOT:-}" = 1 ] || { echo "UNEXPECTED pacman \$* (not as root)" >> "\$ST/sudo.log"; echo "error: you cannot perform this operation unless you are root." >&2; exit 1; }
op="\$1"; shift
[ -e "\$ST/fail-pacman\$op" ] && { echo "error: failed to commit transaction" >&2; exit 1; }
case "\$op" in
    -Sy|-Syu|-S)
        for p; do case "\$p" in -*) ;; *) grep -qx "\$p" '$REPOS' || { echo "error: target not found: \$p" >&2; exit 1; } ;; esac; done
        for p; do case "\$p" in -*) ;; *) add_pkg "\$p" ;; esac; done ;;
    -Rdd) for p; do case "\$p" in -*) ;; *) grep -vx "\$p" "\$ST/pkgs" > "\$ST/pkgs.tmp"; mv "\$ST/pkgs.tmp" "\$ST/pkgs" ;; esac; done ;;
    *) echo "UNEXPECTED pacman \$op \$*" >> "\$ST/sudo.log"; exit 1 ;;
esac
EOF
    printf '#!/bin/sh\nprintf "core\\nextra\\nmultilib\\n"\n' > "$SB/pacman-conf"
    cat > "$SB/systemctl" <<EOF
#!/bin/bash
ST='$ST' SYS='$SYS'
f="\$ST/enabled"
[ "\$1" = --global ] && { f="\$ST/enabled-global"; shift; }
cmd="\$1"; shift
now=0; [ "\${1:-}" = --now ] && { now=1; shift; }
case "\$cmd" in
    is-enabled) if grep -qx "\$1" "\$f"; then echo enabled; else echo disabled; exit 1; fi ;;
    is-active) exit 3 ;;
    cat) grep -qx "\$1" "\$ST/units" ;;
    list-unit-files) grep '^netctl' "\$f" | sed 's/\$/ enabled enabled/'; exit 0 ;;
    list-units) exit 0 ;;
    enable|disable)
        [ "\${SLEEK_STUB_ROOT:-}" = 1 ] || { echo "UNEXPECTED systemctl \$cmd \$* (not as root)" >> "\$ST/sudo.log"; exit 1; }
        for u; do
            [ -e "\$ST/fail-\$cmd-\$u" ] && { echo "Failed to \$cmd unit \$u" >&2; exit 1; }
            if [ "\$cmd" = enable ]; then
                [ "\$f" = "\$ST/enabled-global" ] || grep -qx "\$u" "\$ST/units" || { echo "Unit \$u does not exist" >&2; exit 1; }
                grep -qx "\$u" "\$f" || echo "\$u" >> "\$f"
            else
                grep -vx "\$u" "\$f" > "\$f.tmp"; mv "\$f.tmp" "\$f"
                l="\$SYS/etc/systemd/system/display-manager.service"
                [ -L "\$l" ] && [ "\$(basename "\$(readlink "\$l")")" = "\$u" ] && rm -f "\$l"
            fi
        done ;;
    *) echo "UNEXPECTED systemctl \$cmd \$*" >> "\$ST/sudo.log"; exit 1 ;;
esac
EOF
    printf '#!/bin/sh\n[ "$1" = passwd ] || exit 2\necho "$2:x:1000:1000::/home/$2:$(cat "%s/shell")"\n' "$ST" > "$SB/getent"
    printf '#!/bin/sh\necho "UNEXPECTED mkinitcpio $* (not as root)" >> "%s/sudo.log"; exit 1\n' "$ST" > "$SB/mkinitcpio"
    chmod +x "$SB"/*
}

# A minimal PATH: the tools install.sh needs, no sudo, no pacman, no package-provided programs.
MIN="$TMPROOT/minbin"; mkdir -p "$MIN"
for c in bash sh env id date cat sed awk grep sort cut tr head tail mkdir dirname basename readlink printf uname \
         sha256sum find mktemp rm cp mv chmod install ln stat wc ls touch cmp diff tee xargs sleep realpath comm \
         uniq true false sync rmdir; do
    p="$(command -v "$c")" && ln -sf "$p" "$MIN/$c"
done

BWRAP=()
if command -v bwrap >/dev/null 2>&1 && bwrap --ro-bind / / --bind "$TMPROOT" "$TMPROOT" --dev /dev --proc /proc --unshare-net --die-with-parent true 2>/dev/null; then
    BWRAP=(bwrap --ro-bind / / --bind "$TMPROOT" "$TMPROOT" --dev /dev --proc /proc --unshare-net --die-with-parent)
    pass "sandbox: bubblewrap with a read-only /"
else
    skip "sandbox" "bwrap unavailable: stubs only"
fi

# run NAME ARGS...: install.sh in the scenario's fixture; output in $OUT, status in $RC
run() {
    local n="$1"; shift
    OUT="$TMPROOT/$n/out.log"
    "${BWRAP[@]}" env -i HOME="$H" PATH="$SB:$MIN" TERM=dumb TMPDIR="$TMPROOT/$n/tmp" XDG_RUNTIME_DIR="$TMPROOT/$n/tmp" \
        SLEEK_SYS_ROOT="$SYS" SLEEK_SUDO="$SB/sudo" ${PROMPT_IN:+SLEEK_PROMPT_IN="$PROMPT_IN"} \
        "$REPO/install.sh" "$@" >"$OUT" 2>&1 </dev/null
    RC=$?
}
sudo_has() { grep -qxE -- "$1" "$ST/sudo.log"; }
no_unexpected() { ! grep -q UNEXPECTED "$ST/sudo.log"; }
show() { echo "rc=$RC"; tail -n 25 "$OUT"; echo "--- sudo"; cat "$ST/sudo.log"; }
# ck NAME SHELL-CODE: like check, but shows the installer output and the sudo log on failure
ck() { local d="$1"; shift; if bash -c "$*" >/dev/null 2>&1; then pass "$d"; else fail "$d"; show | sed 's/^/        | /'; fi; }

# ---------------------------------------------------------------- A: fresh hybrid laptop
new_system a
pci 0000:01:00.0 10de 1f91 nouveau
pci 0000:05:00.0 1002 15d8 amdgpu
battery
enable_unit systemd-networkd.service; enable_unit iwd.service
run a --yes
A_SYS="$SYS" A_ST="$ST" A_H="$H" A_SB="$SB"
ck "A: exits 0 with every check passing" "[ $RC = 0 ] && grep -q '^Installed\|Installed' '$OUT'"
ck "A: no unexpected privileged call" "! grep -q UNEXPECTED '$ST/sudo.log'"
ck "A: keyring refreshed first" "head -n1 '$ST/sudo.log' | grep -qx 'pacman -Sy --needed --noconfirm archlinux-keyring'"
SYU="$(grep '^pacman -Syu --needed --noconfirm ' "$ST/sudo.log" | head -n1)"
for p in hyprland quickshell greetd firefox nvidia-open nvidia-utils libva-nvidia-driver nvidia-prime vulkan-radeon \
         pipewire-pulse wireplumber networkmanager bluez power-profiles-daemon zsh ttf-jetbrains-mono-nerd hyprpolkitagent; do
    if [[ " $SYU " == *" $p "* ]]; then pass "A: pacman -Syu installs $p"; else fail "A: pacman -Syu installs $p"; fi
done
check "A: one pacman -Syu with the desktop, driver, greetd and firefox" test -n "$SYU"
check "A: no display manager other than greetd queued" bash -c "! grep -qwE 'sddm|gdm|lightdm' <<<'$SYU'"
check "A: NVIDIA modprobe options written" grep -qx 'options nvidia_drm modeset=1 fbdev=1' "$SYS/etc/modprobe.d/sleek-shell-nvidia.conf"
check "A: video memory preserved across suspend" grep -qx 'options nvidia NVreg_PreserveVideoMemoryAllocations=1' "$SYS/etc/modprobe.d/sleek-shell-nvidia.conf"
check "A: initramfs regenerated" test -e "$ST/initramfs"
for u in nvidia-suspend nvidia-resume nvidia-hibernate; do check "A: $u.service enabled" grep -qx "$u.service" "$ST/enabled"; done
check "A: greeter installed and enabled" sh -c "grep -q sleek-shell '$SYS/etc/greetd/config.toml' && grep -qx greetd.service '$ST/enabled' && [ \"\$(readlink '$SYS/etc/systemd/system/display-manager.service')\" = /usr/lib/systemd/system/greetd.service ]"
check "A: greeter run from the installed copy" grep -qE "^bash $H/.local/share/sleek-shell/greeter/install.sh --enable --yes --replace$" "$ST/sudo.log"
check "A: NetworkManager enabled without --now (networkd still running)" sh -c "grep -qx 'systemctl enable NetworkManager.service' '$ST/sudo.log' && grep -qx NetworkManager.service '$ST/enabled'"
check "A: systemd-networkd disabled, not stopped" sh -c "grep -qx 'systemctl disable systemd-networkd.service' '$ST/sudo.log' && ! grep -q 'stop' '$ST/sudo.log'"
check "A: iwd kept as the NetworkManager Wi-Fi backend" sh -c "grep -qx iwd.service '$ST/enabled' && grep -qx 'wifi.backend=iwd' '$SYS/etc/NetworkManager/conf.d/sleek-shell-iwd.conf'"
check "A: PipeWire user units enabled globally" sh -c "for u in pipewire.socket pipewire-pulse.socket wireplumber.service; do grep -qx \$u '$ST/enabled-global' || exit 1; done"
check "A: bluetooth and power-profiles-daemon enabled now" sh -c "grep -qx 'systemctl enable --now bluetooth.service' '$ST/sudo.log' && grep -qx 'systemctl enable --now power-profiles-daemon.service' '$ST/sudo.log'"
check "A: login shell changed from bash to zsh" sh -c "grep -qE '^usermod -s $SB/zsh ' '$ST/sudo.log' && [ \"\$(cat '$ST/shell')\" = '$SB/zsh' ]"
check "A: laptop idle defaults: lock 10, screen off 15, suspend 30" "$PY3" -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if (d['idleLockMin'],d['idleScreenOffMin'],d['idleSuspendMin'])==(10,15,30) else 1)" "$H/.config/sleek-shell/settings.json"
check "A: laptop battery timeouts: on, 5, 10, 15" "$PY3" -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if (d['idleBatterySeparate'],d['idleBatteryLockMin'],d['idleBatteryScreenOffMin'],d['idleBatterySuspendMin'])==(True,5,10,15) else 1)" "$H/.config/sleek-shell/settings.json"
check "A: report lists the battery timeouts" grep -q '^battery:  lock 5 min, screen off 10 min, suspend 15 min' "$H/.local/share/sleek-shell/install-report.txt"
check "A: firefox is the default browser" grep -qx 'x-scheme-handler/https=firefox.desktop' "$H/.config/mimeapps.list"
check "A: zshrc, hypr, quickshell, kitty, rofi installed" sh -c "cmp -s '$REPO/defaults/zsh/zshrc' '$H/.zshrc' && [ -f '$H/.config/hypr/hyprland.lua' ] && [ -d '$H/.config/quickshell' ] && [ -f '$H/.config/kitty/kitty.conf' ] && [ -f '$H/.config/rofi/config.rasi' ]"
check "A: kitty and rofi theming enabled" sh -c "grep -q '\"kitty\"' '$H/.config/sleek-shell/app-themes.json' && grep -q '\"rofi\"' '$H/.config/sleek-shell/app-themes.json'"
check "A: home folders created" test -f "$H/.config/user-dirs.dirs"
check "A: report lists the checks, no failure" sh -c "grep -q 'ok    NetworkManager enabled' '$H/.local/share/sleek-shell/install-report.txt' && ! grep -q FAIL '$H/.local/share/sleek-shell/install-report.txt'"
check "A: system change log written with undo hints" sh -c "grep -q 'undo: sudo usermod -s /bin/bash' '$H/.local/share/sleek-shell/system-changes.log' && grep -q 'file written: /etc/modprobe.d/sleek-shell-nvidia.conf' '$H/.local/share/sleek-shell/system-changes.log'"
check "A: reboot is asked for" grep -q 'Reboot now' "$OUT"

# ---------------------------------------------------------------- C: second run is idempotent
cp "$ST/sudo.log" "$ST/sudo.first"; : > "$ST/sudo.log"; rm -f "$ST/initramfs"
run a --yes
ck "C: rerun exits 0" "[ $RC = 0 ]"
check "C: rerun changes no service, shell or system file" sh -c "! grep -qE '^(systemctl (enable|disable)|usermod|install|mkinitcpio)' '$ST/sudo.log'"
check "C: rerun refreshes the greeter, does not re-enable it" sh -c "grep -qE '/greeter/install.sh install$' '$ST/sudo.log' && ! grep -q -- '--enable' '$ST/sudo.log'"
check "C: rerun keeps the browser and idle settings" sh -c "grep -qx 'x-scheme-handler/https=firefox.desktop' '$H/.config/mimeapps.list' && grep -q '\"idleSuspendMin\": 30' '$H/.config/sleek-shell/settings.json'"
check "C: no backups made on rerun" test ! -d "$H/.local/share/sleek-shell-backups"

# ---------------------------------------------------------------- D: dry run and --check change nothing
new_system d
pci 0000:00:02.0 8086 9a49 i915
run d --dry-run
ck "D: dry run exits 0" "[ $RC = 0 ]"
check "D: dry run calls no sudo" test ! -s "$ST/sudo.log"
check "D: dry run writes nothing in the home" test -z "$(ls -A "$H")"
check "D: dry run shows the pacman command" grep -q 'would run sudo pacman -Syu --needed --noconfirm .*hyprland' "$OUT"
check "D: dry run shows intel media driver and greetd" sh -c "grep -q 'intel-media-driver' '$OUT' && grep -q 'greetd' '$OUT'"
run d --check
check "D: --check on a fresh system exits 3 and changes nothing" sh -c "[ $RC = 3 ] && [ ! -s '$ST/sudo.log' ] && [ -z \"\$(ls -A '$H')\" ]"
check "D: --check lists the packages it would install" grep -q 'packages ./install.sh installs' "$OUT"
PROMPT_IN="" run d
check "D: no terminal and no --yes: refuses, changes nothing" sh -c "[ $RC != 0 ] && grep -q 'not a terminal' '$OUT' && [ ! -s '$ST/sudo.log' ] && [ -z \"\$(ls -A '$H')\" ]"
echo n > "$TMPROOT/no"
PROMPT_IN="$TMPROOT/no" run d --browser firefox --greeter keep --idle balanced
check "D: answering no to 'Install now?' changes nothing" sh -c "grep -q 'Nothing changed' '$OUT' && [ ! -s '$ST/sudo.log' ]"

# ---------------------------------------------------------------- B: legacy NVIDIA, Chrome, sddm replaced
new_system b
pci 0000:01:00.0 10de 1c8d nouveau
pci 0000:00:02.0 8086 3e9b i915
installed pulseaudio tuned
dm sddm
run b --yes --nvidia 580xx --browser chrome --greeter sleek
ck "B: exits 0" "[ $RC = 0 ]"
ck "B: no unexpected privileged call" "! grep -q UNEXPECTED '$ST/sudo.log'"
check "B: pulseaudio removed before the upgrade" sh -c "grep -n '' '$ST/sudo.log' | grep -q '^2:pacman -Rdd --noconfirm pulseaudio$' && ! grep -qx pulseaudio '$ST/pkgs'"
check "B: power-profiles-daemon not installed next to tuned" sh -c "! grep -q power-profiles-daemon '$ST/sudo.log' && grep -q 'tuned is installed' '$OUT'"
check "B: yay built from the AUR as the user" sh -c "grep -q '^git clone --depth 1 https://aur.archlinux.org/yay-bin.git' '$ST/cmd.log' && grep -q '^makepkg -si --noconfirm' '$ST/cmd.log' && ! grep -q makepkg '$ST/sudo.log'"
check "B: Chrome and nvidia-580xx from the AUR" grep -qE '^yay -S --needed --noconfirm --answerdiff None --answerclean None .*google-chrome' "$ST/cmd.log"
check "B: AUR packages installed" sh -c "grep -qx nvidia-580xx-dkms '$ST/pkgs' && grep -qx google-chrome '$ST/pkgs'"
check "B: base-devel and git queued for the AUR build" sh -c "grep '^pacman -Syu' '$ST/sudo.log' | grep -qw base-devel"
check "B: sddm disabled, greetd enabled" sh -c "grep -qx 'systemctl disable sddm.service' '$ST/sudo.log' && ! grep -qx sddm.service '$ST/enabled' && grep -qx greetd.service '$ST/enabled'"
check "B: chrome is the default browser" grep -qx 'x-scheme-handler/https=google-chrome.desktop' "$H/.config/mimeapps.list"
check "B: desktop idle defaults never suspend" grep -q '"idleSuspendMin": 0' "$H/.config/sleek-shell/settings.json"
check "B: desktop has no separate battery timeouts" "$PY3" -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get('idleBatterySeparate') is False and 'idleBatteryLockMin' not in d else 1)" "$H/.config/sleek-shell/settings.json"

new_system b2
pci 0000:00:02.0 8086 3e9b i915
dm sddm
run b2 --yes
ck "B2: --yes keeps another display manager" "[ $RC = 0 ] && grep -qx sddm.service '$ST/enabled' && ! grep -q greetd '$ST/sudo.log' && ! grep -q 'disable sddm' '$ST/sudo.log'"
check "B2: plan says the login screen is kept" grep -q 'login screen  sddm (kept)' "$OUT"

# ---------------------------------------------------------------- E: leftovers of an earlier attempt
new_system e
pci 0000:00:02.0 8086 9a49 i915
mkdir -p "$H/.config/hypr" "$H/.config/kitty"
printf '# auto-generated by Hyprland\nautogenerated = 1\nmonitor=,preferred,auto,auto\n' > "$H/.config/hypr/hyprland.conf"
printf '# Lines configured by zsh-newuser-install\n# End of lines configured by zsh-newuser-install\n' > "$H/.zshrc"
cp "$REPO/defaults/kitty/kitty.conf" "$H/.config/kitty/kitty.conf"
run e --yes --browser none --keep-shell
ck "E: exits 0" "[ $RC = 0 ]"
check "E: autogenerated Hyprland config replaced and backed up" sh -c "[ -f '$H/.config/hypr/hyprland.lua' ] && [ ! -e '$H/.config/hypr/hyprland.conf' ] && find '$H/.local/share/sleek-shell-backups' -name hyprland.conf | grep -q ."
check "E: empty zsh-newuser zshrc replaced and backed up" sh -c "cmp -s '$REPO/defaults/zsh/zshrc' '$H/.zshrc' && find '$H/.local/share/sleek-shell-backups' -name .zshrc | grep -q ."
check "E: identical kitty.conf adopted, kitty theming on" sh -c "grep -q 'adopt .*kitty.conf' '$OUT' && grep -q '\"kitty\"' '$H/.config/sleek-shell/app-themes.json'"
check "E: --keep-shell leaves the login shell" sh -c "! grep -q usermod '$ST/sudo.log' && [ \"\$(cat '$ST/shell')\" = /bin/bash ]"
check "E: --browser none sets no default" test ! -e "$H/.config/mimeapps.list"

# ---------------------------------------------------------------- failures
new_system f1
pci 0000:00:02.0 8086 9a49 i915
touch "$ST/fail-pacman-Syu"
run f1 --yes
check "F: pacman failure stops before the home is touched" sh -c "[ $RC != 0 ] && grep -q 'pacman failed' '$OUT' && [ ! -e '$H/.config/quickshell' ] && [ ! -e '$H/.local/share/sleek-shell/manifest.tsv' ]"
check "F: pacman failure is not followed by service changes" sh -c "! grep -q '^systemctl' '$ST/sudo.log'"
rm -f "$ST/fail-pacman-Syu"; : > "$ST/sudo.log"
touch "$ST/fail-enable-bluetooth.service"
run f1 --yes
check "F: bluetooth failure is a warning and a failed check (exit 4)" sh -c "[ $RC = 4 ] && grep -q 'could not enable bluetooth.service' '$OUT' && grep -q 'FAIL  bluetooth.service enabled' '$H/.local/share/sleek-shell/install-report.txt'"
check "F: the rest still installed after the bluetooth failure" sh -c "grep -qx NetworkManager.service '$ST/enabled' && [ -f '$H/.local/share/sleek-shell/manifest.tsv' ]"

new_system f2
pci 0000:00:02.0 8086 9a49 i915
touch "$ST/fail-yay"
run f2 --yes --browser chrome
check "F: AUR failure is a warning; the desktop is installed (exit 4)" sh -c "[ $RC = 4 ] && grep -q 'could not install: google-chrome' '$OUT' && [ -f '$H/.config/hypr/hyprland.lua' ] && grep -qx greetd.service '$ST/enabled'"

new_system f3
pci 0000:00:02.0 8086 9a49 i915
touch "$ST/fail-greeter"
run f3 --yes
check "F: greeter failure leaves the login screen alone (exit 4)" sh -c "[ $RC = 4 ] && grep -q 'greeter installer failed' '$OUT' && [ ! -e '$SYS/etc/systemd/system/display-manager.service' ]"

# ---------------------------------------------------------------- G: interactive answers
# browser by id, replace sddm (default is no), short timeouts by number (1), Enter at "Install now?"
new_system g
pci 0000:06:00.0 1002 1638 amdgpu
battery
dm sddm
printf 'chromium\ny\n1\n\n' > "$TMPROOT/g-answers"
PROMPT_IN="$TMPROOT/g-answers" run g
ck "G: interactive install exits 0" "[ $RC = 0 ]"
check "G: menus were shown" sh -c "grep -q 'Web browser' '$OUT' && grep -q 'Replace the current login screen (sddm)' '$OUT' && grep -q 'When you are away' '$OUT' && grep -q 'Install now?' '$OUT'"
check "G: chromium installed and made the default" sh -c "grep '^pacman -Syu' '$ST/sudo.log' | grep -qw chromium && grep -qx 'x-scheme-handler/https=chromium.desktop' '$H/.config/mimeapps.list'"
check "G: sddm replaced by the greeter after a yes" sh -c "grep -qx 'systemctl disable sddm.service' '$ST/sudo.log' && grep -qx greetd.service '$ST/enabled'"
check "G: short timeouts on a laptop: 5, 10, 15" "$PY3" -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if (d['idleLockMin'],d['idleScreenOffMin'],d['idleSuspendMin'])==(5,10,15) else 1)" "$H/.config/sleek-shell/settings.json"
check "G: short battery timeouts: 2, 5, 15" "$PY3" -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if (d['idleBatteryLockMin'],d['idleBatteryScreenOffMin'],d['idleBatterySuspendMin'])==(2,5,15) else 1)" "$H/.config/sleek-shell/settings.json"
check "G: AMD only: no NVIDIA packages" sh -c "! grep '^pacman -Syu' '$ST/sudo.log' | grep -q nvidia && grep '^pacman -Syu' '$ST/sudo.log' | grep -qw vulkan-radeon"

check "no stub ever saw a call that was not through sudo" sh -c "! grep -rq 'not as root' '$TMPROOT'/*/state/sudo.log"
finish
