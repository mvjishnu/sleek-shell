# shellcheck shell=bash
# Dependency table and checks. Sourced by install.sh. Read-only: it never installs anything.
#
# Package names: Arch is verified (CachyOS, Arch extra, `pacman -Sp`). Fedora 44, Debian 13 / Ubuntu 26.04 and
# openSUSE Tumbleweed names come from their package indexes and are not install-tested.
#   "-"          not packaged there (see docs/DISTROS.md)
#   "pkg (note)" only in a third-party repository or backports: listed with the note, never installed
#                automatically by --install-deps
#
# id|check|level|arch|fedora|debian|suse|what it is for
#   check: cmd:a/b (any command), py:module, font:Family, icon:Theme, cursor:Theme, portal:name,
#          polkit:agent (an installed polkit agent), qtplugin:dir/file
#   level: required (shell does not start or core features break), recommended (a visible feature or
#          a basic desktop service is missing), optional
DEPS_TABLE='hyprland|cmd:Hyprland|required|hyprland|hyprland (COPR sdegler/hyprland)|hyprland (Debian 13: trixie-backports; Ubuntu: PPA cppiber/hyprland)|hyprland|compositor (0.55+ for the Lua config)
quickshell|cmd:quickshell/qs|required|quickshell|quickshell|quickshell (Debian 13: trixie-backports; Ubuntu: PPA avengemedia/danklinux)|quickshell (OBS home:AvengeMedia:danklinux)|the shell itself
python|cmd:python3|required|python|python3|python3|python3|helper scripts
awww|cmd:awww/awww-daemon|required|awww|-|awww (Ubuntu: PPA razvanalex/hyprland-ppa; Debian: build from source)|awww|wallpaper daemon
wl-clipboard|cmd:wl-copy/wl-paste|required|wl-clipboard|wl-clipboard|wl-clipboard|wl-clipboard|clipboard
cliphist|cmd:cliphist|required|cliphist|cliphist|cliphist|cliphist|clipboard history
rofi|cmd:rofi|required|rofi|rofi|rofi|rofi|launcher and calculator (2.0+ for Wayland; Debian 13 ships 1.7.5)
fontconfig|cmd:fc-cache|required|fontconfig|fontconfig|fontconfig|fontconfig|icon font registration
xdg-utils|cmd:xdg-open|required|xdg-utils|xdg-utils|xdg-utils|xdg-utils|default apps
nerd-font|font:JetBrainsMono Nerd Font|required|ttf-jetbrains-mono-nerd|-|-|-|bar, kitty, rofi and greeter glyphs
kitty|cmd:kitty|recommended|kitty|kitty|kitty|kitty|default terminal (SUPER+T; override with SLEEK_TERMINAL)
file-manager|cmd:dolphin/nautilus/thunar/nemo/caja/pcmanfm-qt/pcmanfm|recommended|dolphin|dolphin|dolphin|dolphin|file manager for SUPER+E (any; Dolphin is suggested when you have none)
portal-hyprland|portal:hyprland|recommended|xdg-desktop-portal-hyprland|xdg-desktop-portal-hyprland (COPR sdegler/hyprland)|xdg-desktop-portal-hyprland (Debian 13: trixie-backports)|xdg-desktop-portal-hyprland|screen sharing and screenshots for apps (XDG portal)
portal-gtk|portal:gtk|recommended|xdg-desktop-portal-gtk|xdg-desktop-portal-gtk|xdg-desktop-portal-gtk|xdg-desktop-portal-gtk|file chooser and settings portal
polkit-agent|polkit:agent|recommended|hyprpolkitagent|polkit-kde|polkit-kde-agent-1|hyprpolkitagent|password prompts when an app needs admin rights
wireplumber|cmd:wpctl|recommended|wireplumber|wireplumber|wireplumber|wireplumber|audio (PipeWire session manager, volume keys)
upower|cmd:upower|recommended|upower|upower|upower|upower|battery widget and panel
networkmanager|cmd:nmcli|recommended|networkmanager|NetworkManager|network-manager|NetworkManager|Wi-Fi panel
libnotify|cmd:notify-send|recommended|libnotify|libnotify|libnotify-bin|libnotify-tools|script notifications
gdbus|cmd:gdbus|recommended|glib2|glib2|libglib2.0-bin|glib2-tools|lock the screen before suspend (listens to logind)
jq|cmd:jq|recommended|jq|jq|jq|jq|theme export to kitty, rofi, GTK, Qt, micro (skipped without it)
grim|cmd:grim|recommended|grim|grim|grim|grim|screenshots, lock screen background
slurp|cmd:slurp|recommended|slurp|slurp|slurp|slurp|region screenshots
inter-font|font:Inter|recommended|inter-font|rsms-inter-fonts|fonts-inter|inter-fonts|UI font (falls back to Noto Sans)
noto-font|font:Noto Sans|recommended|noto-fonts|google-noto-sans-fonts|fonts-noto-core|google-noto-sans-fonts|default app font and UI fallback
papirus|icon:Papirus-Dark|recommended|papirus-icon-theme|papirus-icon-theme|papirus-icon-theme|papirus-icon-theme|default icon theme
cursor|cursor:Adwaita|recommended|adwaita-cursors|adwaita-cursor-theme|adwaita-icon-theme|adwaita-icon-theme|default cursor theme
brightnessctl|cmd:brightnessctl|optional|brightnessctl|brightnessctl|brightnessctl|brightnessctl|backlight keys and slider
playerctl|cmd:playerctl|optional|playerctl|playerctl|playerctl|playerctl|media keys (fall back to the shell)
bluez|cmd:bluetoothctl|optional|bluez-utils|bluez|bluez|bluez|Bluetooth panel
blueman|cmd:blueman-manager|optional|blueman|blueman|blueman|blueman|"Bluetooth settings" button
gobject|py:gi|optional|python-gobject|python3-gobject|python3-gi|python3-gobject|Bluetooth panel helper
nm-editor|cmd:nm-connection-editor|optional|nm-connection-editor|nm-connection-editor|nm-connection-editor|NetworkManager-connection-editor|"Network settings" button (falls back to nmtui in kitty)
power-profiles|cmd:powerprofilesctl|optional|power-profiles-daemon|power-profiles-daemon|power-profiles-daemon|power-profiles-daemon|power profile switch
pipewire-pulse|cmd:pipewire-pulse|optional|pipewire-pulse|pipewire-pulseaudio|pipewire-pulse|pipewire-pulseaudio|PulseAudio apps and pavucontrol
pavucontrol|cmd:pavucontrol|optional|pavucontrol|pavucontrol|pavucontrol|pavucontrol|"More audio settings" button
gsettings|cmd:gsettings|optional|glib2|glib2|libglib2.0-bin|glib2-tools|GTK font/icon settings
kwriteconfig6|cmd:kwriteconfig6|optional|kconfig|kf6-kconfig|libkf6config-bin|kf6-kconfig|Qt/KDE font/icon settings
gtk-launch|cmd:gtk-launch|optional|gtk3|gtk3|libgtk-3-bin|gtk3-tools|open default browser/file manager
nwg-displays|cmd:nwg-displays|optional|nwg-displays|-|nwg-displays|nwg-displays|monitor layout editor
imagemagick|cmd:magick/convert|optional|imagemagick|ImageMagick|imagemagick|ImageMagick|icon theme previews
qt-imageformats|qtplugin:imageformats/libqwebp.so|optional|qt6-imageformats|qt6-qtimageformats|qt6-image-formats-plugins|qt6-imageformats|WebP wallpaper previews
bsdtar|cmd:bsdtar|optional|libarchive|bsdtar|libarchive-tools|bsdtar|unpacking downloaded fonts, icons and cursors
pciutils|cmd:lspci|optional|pciutils|pciutils|pciutils|pciutils|GPU line in the system info
curl|cmd:curl|optional|curl|curl|curl|curl|weather, asset downloads
calc-build|cmd:make/cc|optional|base-devel|make gcc rofi-devel|build-essential|make gcc rofi-devel|faster calculator plugin (falls back to script mode)'

# Display managers are never installed by install.sh (the greeter is separate and optional).
DEPS_DM_PACKAGES=" greetd sddm gdm gdm3 lightdm lxdm ly plasma-login-manager cosmic-greeter xdm slim nodm emptty lemurs "
_DEPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEP_MISSING_REQUIRED=()
DEP_MISSING_RECOMMENDED=()
DEP_MISSING_OPTIONAL=()
DEP_PKGS_CORE=()       # missing required + recommended packages from the distribution's own repositories
DEP_PKGS_OPTIONAL=()   # missing optional packages from the distribution's own repositories
DEP_MANUAL=()          # "id|package|where": missing, only in a third-party repository or backports
DEP_UNPACKAGED=()      # "id|level": missing and not packaged for this family
DEP_VERSION_PROBLEMS=()

_dep_any_file() { local p; for p in "$@"; do compgen -G "$p" >/dev/null && return 0; done; return 1; }

_dep_icon_dirs() {
    local d IFS=:
    printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/icons" "$HOME/.icons"
    for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do printf '%s\n' "${SYS_ROOT:-}$d/icons"; done
}

_dep_has() {
    local spec="$1" kind="${1%%:*}" arg="${1#*:}" c d R="${SYS_ROOT:-}"
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
        icon|cursor)
            while IFS= read -r d; do
                if [ "$kind" = icon ]; then [ -f "$d/$arg/index.theme" ] && return 0
                else [ -d "$d/$arg/cursors" ] && return 0; fi
            done < <(_dep_icon_dirs)
            return 1 ;;
        portal) _dep_any_file "$R/usr/share/xdg-desktop-portal/portals/$arg.portal" ;;
        polkit) SLEEK_SYS_ROOT="$R" "$_DEPS_DIR/../hypr/scripts/polkit-agent.sh" --find >/dev/null 2>&1 ;;
        qtplugin) _dep_any_file "$R/usr/lib/qt6/plugins/$arg" "$R/usr/lib64/qt6/plugins/$arg" "$R/usr/lib/*/qt6/plugins/$arg" ;;
        *) echo "deps: bad check '$spec'" >&2; return 1 ;;
    esac
}

_dep_pkg_for() {   # _dep_pkg_for FAMILY arch fedora debian suse
    case "$1" in
        arch) echo "$2" ;; fedora) echo "$3" ;; debian) echo "$4" ;; suse) echo "$5" ;; *) echo "?" ;;
    esac
}

is_dm_package() { case "$DEPS_DM_PACKAGES" in *" $1 "*) return 0 ;; esac; return 1; }

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
    local fam="$1" id check level a f d s why pkg mark w
    DEP_MISSING_REQUIRED=() DEP_MISSING_RECOMMENDED=() DEP_MISSING_OPTIONAL=() DEP_VERSION_PROBLEMS=()
    DEP_PKGS_CORE=() DEP_PKGS_OPTIONAL=() DEP_MANUAL=() DEP_UNPACKAGED=()
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
            if [ "$pkg" = "-" ] || [ "$pkg" = "?" ]; then
                DEP_UNPACKAGED+=("$id|$level")
            elif [ "${pkg#* (}" != "$pkg" ]; then
                w="${pkg#* (}"; DEP_MANUAL+=("$id|${pkg%% (*}|${w%)}")
            else
                for w in $pkg; do
                    if is_dm_package "$w"; then DEP_MANUAL+=("$id|$w|a display manager: never installed by install.sh")
                    elif [ "$level" = optional ]; then DEP_PKGS_OPTIONAL+=("$w")
                    else DEP_PKGS_CORE+=("$w"); fi
                done
            fi
        fi
        printf '  %-8s %-12s %-16s %s\n' "$mark" "$level" "$id" "$why"
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

# pm_argv FAMILY: sets PM_ARGV to the package-manager install command (without sudo). Returns 1 if unknown.
pm_argv() {
    case "$1" in
        arch) PM_ARGV=(pacman -S --needed) ;;
        fedora) PM_ARGV=(dnf install) ;;
        debian) PM_ARGV=(apt install) ;;
        suse) PM_ARGV=(zypper install) ;;
        *) PM_ARGV=(); return 1 ;;
    esac
}

# uniq_words WORD...: each word once, in order
uniq_words() { printf '%s\n' "$@" | awk 'NF && !seen[$0]++'; }

# install_hint FAMILY [core|optional]: the package-manager command for the missing packages from the
# distribution's own repositories (core = required + recommended)
install_hint() {
    local fam="$1" pkgs=()
    if [ "${2:-core}" = optional ]; then pkgs=("${DEP_PKGS_OPTIONAL[@]}"); else pkgs=("${DEP_PKGS_CORE[@]}"); fi
    [ "${#pkgs[@]}" -gt 0 ] || return 0
    local list; list="$(uniq_words "${pkgs[@]}" | tr '\n' ' ')"; list="${list% }"
    if pm_argv "$fam"; then echo "sudo ${PM_ARGV[*]} $list"
    else echo "install with your package manager: $list"; fi
}

# deps_notes FAMILY: missing dependencies that --install-deps cannot install from the distro repositories
deps_notes() {
    local e id pkg where lvl
    for e in "${DEP_MANUAL[@]}"; do
        IFS='|' read -r id pkg where <<<"$e"
        say "  $id: $pkg is not in the default $1 repositories ($where). See docs/DISTROS.md."
    done
    for e in "${DEP_UNPACKAGED[@]}"; do
        IFS='|' read -r id lvl <<<"$e"
        say "  $id ($lvl): not packaged for $1. See docs/DISTROS.md."
    done
}

# service_hints: services that are installed but not running, and notification daemons that would take
# notifications away from the shell. Prints hints only; never starts or enables anything.
_svc_hint() {   # _svc_hint system|user UNIT COMMAND
    command -v "$3" >/dev/null 2>&1 || return 0
    local sc=(systemctl) how="sudo systemctl enable --now $2"
    [ "$1" = user ] && { sc+=(--user); how="systemctl --user enable --now $2"; }
    "${sc[@]}" cat "$2" >/dev/null 2>&1 || return 0
    "${sc[@]}" is-active --quiet "$2" 2>/dev/null && return 0
    warn "$2 is not running. To start it now and at boot: $how (not run for you)"
}
service_hints() {
    if [ -z "${SYS_ROOT:-}" ] && [ "$(init_system)" = systemd ] && command -v systemctl >/dev/null 2>&1; then
        _svc_hint system NetworkManager.service nmcli
        _svc_hint system bluetooth.service bluetoothctl
        _svc_hint system power-profiles-daemon.service powerprofilesctl
        _svc_hint user pipewire.socket wpctl
        _svc_hint user wireplumber.service wpctl
    fi
    local n
    command -v pgrep >/dev/null 2>&1 || return 0
    for n in mako dunst swaync fnott xfce4-notifyd; do
        pgrep -u "$(id -u)" -x "$n" >/dev/null 2>&1 && warn "$n is running: it takes notifications away from Sleek Shell. Remove it from your autostart."
    done
    return 0
}

# install_deps FAMILY WITH_OPTIONAL: shows the package-manager command for the missing packages from
# the distribution's own repositories, asks on the terminal and runs it. --yes never answers this
# question; without a terminal nothing is installed. Display managers are never installed.
install_deps() {
    local fam="$1" opt="$2" p pkgs=()
    pkgs=("${DEP_PKGS_CORE[@]}")
    [ "$opt" = 1 ] && pkgs+=("${DEP_PKGS_OPTIONAL[@]}")
    mapfile -t pkgs < <(uniq_words "${pkgs[@]}")
    for p in "${pkgs[@]}"; do is_dm_package "$p" && die "refusing to install the display manager $p"; done
    pm_argv "$fam" || { warn "unknown distribution family: install the packages yourself (docs/DISTROS.md)"; return 1; }
    if [ "${#pkgs[@]}" -eq 0 ]; then
        ok "nothing to install from the $fam repositories"
        return 0
    fi
    local cmd=("${PM_ARGV[@]}" "${pkgs[@]}")
    if [ "$(id -u)" != 0 ]; then
        command -v sudo >/dev/null 2>&1 || { warn "sudo not found: run this as root: ${cmd[*]}"; return 1; }
        cmd=(sudo "${cmd[@]}")
    fi
    say "  command: ${cmd[*]}"
    if [ "$DRY" = 1 ]; then say "  dry run: not run"; return 0; fi
    if ! ask "  Run it now? Your package manager shows the full list and asks again."; then
        say "  not run: nothing was installed"
        return 1
    fi
    "${cmd[@]}" || { warn "the package manager failed or was cancelled"; return 1; }
    hash -r
    unset _DEP_FONTS
    return 0
}
