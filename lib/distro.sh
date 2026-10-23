# shellcheck shell=bash
# Distro, init system and display-manager detection. Sourced by install.sh / uninstall.sh.
# Read-only: nothing here changes the system.
#
# Test hooks (tests/ only):
#   SLEEK_OS_RELEASE  path of the os-release file to read (default /etc/os-release, then /usr/lib/os-release)
#   SLEEK_SYS_ROOT    prefix for /etc and /run lookups (default: empty = the real system)

SYS_ROOT="${SLEEK_SYS_ROOT:-}"

DISTRO_ID=unknown
DISTRO_NAME=unknown
DISTRO_VERSION=""
DISTRO_FAMILY=unknown
DISTRO_SUPPORT=untested

os_release_file() {
    if [ -n "${SLEEK_OS_RELEASE:-}" ]; then printf '%s\n' "$SLEEK_OS_RELEASE"; return; fi
    local f
    for f in "$SYS_ROOT/etc/os-release" "$SYS_ROOT/usr/lib/os-release"; do
        [ -r "$f" ] && { printf '%s\n' "$f"; return; }
    done
    printf '%s\n' "$SYS_ROOT/etc/os-release"
}

# os_release_get FILE KEY: parse one key without sourcing the file (it is data, not code).
os_release_get() {
    local line val
    line="$(grep -E "^$2=" "$1" 2>/dev/null | tail -n1)" || true
    val="${line#*=}"
    val="${val%\"}"; val="${val#\"}"
    val="${val%\'}"; val="${val#\'}"
    printf '%s\n' "$val"
}

# family_for "ID ID_LIKE..." -> arch | fedora | debian | suse | unknown
family_for() {
    local w
    for w in $1; do
        case "$w" in
            arch|archarm|cachyos|endeavouros|manjaro|garuda|artix|arcolinux|rebornos) echo arch; return ;;
            fedora|rhel|centos|nobara|ultramarine|bazzite|rocky|almalinux) echo fedora; return ;;
            debian|ubuntu|linuxmint|pop|elementary|zorin|kali|neon|raspbian) echo debian; return ;;
            opensuse*|suse|sles|sled) echo suse; return ;;
        esac
    done
    echo unknown
}

detect_distro() {
    local f; f="$(os_release_file)"
    if [ ! -r "$f" ]; then
        DISTRO_ID=unknown DISTRO_NAME=unknown DISTRO_FAMILY=unknown DISTRO_SUPPORT=unsupported
        return 0
    fi
    DISTRO_ID="$(os_release_get "$f" ID)"; DISTRO_ID="${DISTRO_ID:-unknown}"
    DISTRO_NAME="$(os_release_get "$f" PRETTY_NAME)"; DISTRO_NAME="${DISTRO_NAME:-$DISTRO_ID}"
    DISTRO_VERSION="$(os_release_get "$f" VERSION_ID)"
    DISTRO_FAMILY="$(family_for "$DISTRO_ID $(os_release_get "$f" ID_LIKE)")"
    case "$DISTRO_FAMILY" in
        arch)   DISTRO_SUPPORT=supported ;;      # developed and tested on CachyOS
        fedora) DISTRO_SUPPORT=experimental ;;   # Hyprland/Quickshell from COPR, untested
        suse)   DISTRO_SUPPORT=experimental ;;   # Tumbleweed only, untested
        debian) DISTRO_SUPPORT=experimental ;;   # distro Hyprland is too old; build from source
        *)      DISTRO_SUPPORT=unsupported ;;
    esac
}

# init_system -> systemd | other
init_system() {
    if [ -d "$SYS_ROOT/run/systemd/system" ]; then echo systemd; else echo other; fi
}

# display_manager -> name of the unit behind display-manager.service, or "none"
display_manager() {
    local l="$SYS_ROOT/etc/systemd/system/display-manager.service" t
    if [ -L "$l" ]; then
        t="$(readlink "$l")"
        t="${t##*/}"
        echo "${t%.service}"
        return
    fi
    echo none
}

# greetd_uses_sleek -> yes | no
greetd_uses_sleek() {
    if grep -qs 'sleek-shell' "$SYS_ROOT/etc/greetd/config.toml"; then echo yes; else echo no; fi
}
