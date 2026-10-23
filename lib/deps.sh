# shellcheck shell=bash
# Dependency table and checks. Sourced by install.sh. Read-only: it never installs anything.
#
# Package names: Arch is verified (CachyOS, Arch extra). Fedora, Debian/Ubuntu and openSUSE names are
# best-effort and untested; "-" means not packaged there (build from source, see docs/DISTROS.md).
#
# id|check|level|arch|fedora|debian|suse|what it is for
#   check: cmd:a/b (any command), py:module, font:Family
#   level: required (shell does not start or core features break), recommended, optional
DEPS_TABLE='hyprland|cmd:Hyprland|required|hyprland|hyprland (COPR solopasha/hyprland)|-|hyprland|compositor (0.55+ for the Lua config)
quickshell|cmd:quickshell/qs|required|quickshell|quickshell (COPR errornointernet/quickshell)|-|-|the shell itself
python|cmd:python3|required|python|python3|python3|python3|helper scripts
awww|cmd:awww/awww-daemon|required|awww|-|-|-|wallpaper daemon
wl-clipboard|cmd:wl-copy/wl-paste|required|wl-clipboard|wl-clipboard|wl-clipboard|wl-clipboard|clipboard
cliphist|cmd:cliphist|required|cliphist|cliphist|cliphist|cliphist|clipboard history
rofi|cmd:rofi|required|rofi|rofi-wayland|-|rofi|launcher (2.0+, Wayland)
fontconfig|cmd:fc-cache|required|fontconfig|fontconfig|fontconfig|fontconfig|icon font registration
xdg-utils|cmd:xdg-open|required|xdg-utils|xdg-utils|xdg-utils|xdg-utils|default apps
nerd-font|font:JetBrainsMono Nerd Font|required|ttf-jetbrains-mono-nerd|-|-|-|bar and greeter glyphs
wireplumber|cmd:wpctl|recommended|wireplumber|wireplumber|wireplumber|wireplumber|volume
networkmanager|cmd:nmcli|recommended|networkmanager|NetworkManager|network-manager|NetworkManager|Wi-Fi panel
libnotify|cmd:notify-send|recommended|libnotify|libnotify|libnotify-bin|libnotify-tools|script notifications
jq|cmd:jq|recommended|jq|jq|jq|jq|theme export to kitty, rofi, GTK, Qt, micro (skipped without it)
grim|cmd:grim|recommended|grim|grim|grim|grim|screenshots, lock screen background
slurp|cmd:slurp|recommended|slurp|slurp|slurp|slurp|region screenshots
kitty|cmd:kitty|recommended|kitty|kitty|kitty|kitty|default terminal (SUPER+T; override with SLEEK_TERMINAL)
inter-font|font:Inter|recommended|inter-font|rsms-inter-fonts|fonts-inter|google-inter-fonts|UI font (falls back to Noto Sans)
brightnessctl|cmd:brightnessctl|optional|brightnessctl|brightnessctl|brightnessctl|brightnessctl|backlight keys and slider
bluez|cmd:bluetoothctl|optional|bluez-utils|bluez|bluez|bluez|Bluetooth panel
gobject|py:gi|optional|python-gobject|python3-gobject|python3-gi|python3-gobject|Bluetooth panel helper
power-profiles|cmd:powerprofilesctl|optional|power-profiles-daemon|power-profiles-daemon|power-profiles-daemon|power-profiles-daemon|power profile switch
playerctl|cmd:playerctl|optional|playerctl|playerctl|playerctl|playerctl|media controls
gsettings|cmd:gsettings|optional|glib2|glib2|libglib2.0-bin|glib2-tools|GTK font/icon settings
kwriteconfig6|cmd:kwriteconfig6|optional|kconfig|kf6-kconfig|libkf6config-bin|kf6-kconfig|Qt/KDE font/icon settings
nwg-displays|cmd:nwg-displays|optional|nwg-displays|nwg-displays|nwg-displays|nwg-displays|monitor layout editor
pavucontrol|cmd:pavucontrol|optional|pavucontrol|pavucontrol|pavucontrol|pavucontrol|"More audio settings" button
imagemagick|cmd:magick|optional|imagemagick|ImageMagick|imagemagick|ImageMagick|icon theme previews
curl|cmd:curl|optional|curl|curl|curl|curl|weather, asset downloads
gtk-launch|cmd:gtk-launch|optional|gtk3|gtk3|libgtk-3-bin|gtk3-tools|open default browser/file manager
calc-build|cmd:make/cc|optional|base-devel|make gcc rofi-devel|build-essential|make gcc rofi-devel|faster calculator plugin (falls back to script mode)'

DEP_MISSING_REQUIRED=()
DEP_MISSING_RECOMMENDED=()
DEP_MISSING_OPTIONAL=()
DEP_PKGS_MISSING=()
DEP_VERSION_PROBLEMS=()

_dep_has() {
    local spec="$1" kind="${1%%:*}" arg="${1#*:}" c
    case "$kind" in
        cmd)
            local IFS=/
            for c in $arg; do command -v "$c" >/dev/null 2>&1 && return 0; done
            return 1 ;;
        py) command -v python3 >/dev/null 2>&1 && python3 -c "import $arg" >/dev/null 2>&1 ;;
        font)
            command -v fc-list >/dev/null 2>&1 || return 1
            [ -n "${_DEP_FONTS+x}" ] || _DEP_FONTS="$(fc-list : family 2>/dev/null || true)"
            grep -qiF -- "$arg" <<<"$_DEP_FONTS" ;;
        *) echo "deps: bad check '$spec'" >&2; return 1 ;;
    esac
}

_dep_pkg_for() {   # _dep_pkg_for FAMILY arch fedora debian suse
    case "$1" in
        arch) echo "$2" ;; fedora) echo "$3" ;; debian) echo "$4" ;; suse) echo "$5" ;; *) echo "?" ;;
    esac
}

# version_ge A B -> 0 when A >= B (dotted numeric)
version_ge() {
    [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

hyprland_version() {
    command -v Hyprland >/dev/null 2>&1 || return 1
    Hyprland --version 2>/dev/null | awk 'match($0,/[0-9]+\.[0-9]+(\.[0-9]+)?/){if(!f)print substr($0,RSTART,RLENGTH); f=1} END{exit !f}'
}

quickshell_version() {
    local q; q="$(command -v quickshell || command -v qs)" || return 1
    "$q" --version 2>/dev/null | awk 'match($0,/[0-9]+\.[0-9]+(\.[0-9]+)?/){if(!f)print substr($0,RSTART,RLENGTH); f=1} END{exit !f}'
}

rofi_version() {
    command -v rofi >/dev/null 2>&1 || return 1
    rofi -v 2>/dev/null | awk 'match($0,/[0-9]+\.[0-9]+(\.[0-9]+)?/){if(!f)print substr($0,RSTART,RLENGTH); f=1} END{exit !f}'
}

# check_deps FAMILY: fills the DEP_* arrays and prints a table. Returns 1 if a required dep is missing
# or too old.
check_deps() {
    local fam="$1" id check level a f d s why pkg mark
    DEP_MISSING_REQUIRED=() DEP_MISSING_RECOMMENDED=() DEP_MISSING_OPTIONAL=() DEP_PKGS_MISSING=() DEP_VERSION_PROBLEMS=()
    while IFS='|' read -r id check level a f d s why; do
        [ -n "$id" ] || continue
        if _dep_has "$check"; then
            mark="ok"
        else
            mark="MISSING"
            pkg="$(_dep_pkg_for "$fam" "$a" "$f" "$d" "$s")"
            case "$level" in
                required) DEP_MISSING_REQUIRED+=("$id") ;;
                recommended) DEP_MISSING_RECOMMENDED+=("$id") ;;
                *) DEP_MISSING_OPTIONAL+=("$id") ;;
            esac
            [ "$pkg" = "-" ] || [ "$pkg" = "?" ] || DEP_PKGS_MISSING+=("${pkg%% (*}")
        fi
        printf '  %-8s %-12s %-15s %s\n' "$mark" "$level" "$id" "$why"
    done <<< "$DEPS_TABLE"

    local v
    if v="$(hyprland_version)" && [ -n "$v" ] && ! version_ge "$v" 0.55; then
        DEP_VERSION_PROBLEMS+=("Hyprland $v is too old: 0.55 or newer is needed for the Lua config")
    fi
    if v="$(quickshell_version)" && [ -n "$v" ] && ! version_ge "$v" 0.2; then
        DEP_VERSION_PROBLEMS+=("Quickshell $v is too old: 0.2 or newer is needed (tested with 0.3.2)")
    fi
    if v="$(rofi_version)" && [ -n "$v" ] && ! version_ge "$v" 2.0; then
        DEP_VERSION_PROBLEMS+=("rofi $v has no native Wayland support: 2.0 or newer is recommended")
    fi
    [ "${#DEP_MISSING_REQUIRED[@]}" -eq 0 ] || return 1
    local p
    for p in "${DEP_VERSION_PROBLEMS[@]}"; do case "$p" in rofi*) ;; *) return 1 ;; esac; done
    return 0
}

# install_hint FAMILY: the package-manager command for the missing packages (printed, never run)
install_hint() {
    [ "${#DEP_PKGS_MISSING[@]}" -gt 0 ] || return 0
    local list; list="$(printf '%s ' "${DEP_PKGS_MISSING[@]}" | tr ' ' '\n' | awk 'NF && !seen[$0]++' | tr '\n' ' ')"
    list="${list% }"
    case "$1" in
        arch) echo "sudo pacman -S --needed $list" ;;
        fedora) echo "sudo dnf install $list" ;;
        debian) echo "sudo apt install $list" ;;
        suse) echo "sudo zypper install $list" ;;
        *) echo "install with your package manager: $list" ;;
    esac
}
