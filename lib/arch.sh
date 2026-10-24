# shellcheck shell=bash
# The system phase of install.sh on Arch Linux and Arch-based distributions: packages (repositories and
# AUR), GPU driver, services, display manager hand-over, login shell. Needs lib/common.sh, lib/priv.sh,
# lib/distro.sh, lib/deps.sh and lib/gpu.sh.
#
# Everything privileged goes through priv()/priv_write() (lib/priv.sh): printed in a dry run, logged
# otherwise. Read-only queries (pacman -Q/-Sl, systemctl is-enabled, getent) run directly.
# Tests stub pacman, systemctl, getent, git, makepkg, yay on PATH and point SLEEK_SUDO at a recorder.

# Packages every Sleek Shell desktop gets on Arch, on top of the dependency table (lib/deps.sh) and the
# GPU plan (lib/gpu.sh). Concrete names only: no provider prompts under --noconfirm.
ARCH_BASE_PKGS=(
    hyprland quickshell xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    qt6-wayland qt5-wayland polkit hyprpolkitagent
    pipewire pipewire-alsa pipewire-pulse wireplumber sof-firmware
    networkmanager bluez bluez-utils upower power-profiles-daemon
    xdg-user-dirs xdg-utils gvfs git unzip archlinux-xdg-menu
    kitty awww rofi wl-clipboard cliphist grim slurp jq libnotify pavucontrol brightnessctl playerctl
    zsh zsh-completions zsh-autosuggestions zsh-syntax-highlighting fzf
    noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd inter-font papirus-icon-theme adwaita-cursors
)
# Installed audio servers that conflict with PipeWire's replacements (removed with pacman -Rdd first).
ARCH_AUDIO_CONFLICTS=(pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-jack pulseaudio-zeroconf
    pulseaudio-equalizer pulseaudio-lirc pulseaudio-rtp pipewire-media-session)
# Power daemons that replace power-profiles-daemon (it is not installed next to them).
ARCH_POWER_ALTERNATIVES=(tuned-ppd tuned tlp auto-cpufreq)

# id|label|package|desktop file(s)
BROWSERS='firefox|Firefox|firefox|firefox.desktop
chromium|Chromium|chromium|chromium.desktop
vivaldi|Vivaldi|vivaldi|vivaldi-stable.desktop
brave|Brave|brave-bin|brave-browser.desktop
zen|Zen Browser|zen-browser-bin|zen.desktop zen-browser.desktop
chrome|Google Chrome|google-chrome|google-chrome.desktop
epiphany|GNOME Web|epiphany|org.gnome.Epiphany.desktop'

PKG_REPO=()      # repository packages to install (pacman -Syu --needed)
PKG_AUR=()       # AUR packages (yay/paru, bootstrapped when missing)
PKG_REMOVE=()    # installed packages removed first (conflicts)
ARCH_NOTES=()
SYS_CHANGES=()   # one line per system change, written to the install report and shown by uninstall.sh

declare -A _REPO_SET=()
_repo_loaded=0
# in_repos NAME: NAME is a package in an enabled repository (pacman -Slq, read once)
in_repos() {
    if [ "$_repo_loaded" = 0 ]; then
        local p
        while IFS= read -r p; do [ -n "$p" ] && _REPO_SET["$p"]=1; done < <(pacman -Slq 2>/dev/null)
        _repo_loaded=1
    fi
    [ -n "${_REPO_SET[$1]+x}" ]
}
repo_set_size() { in_repos __load__ || true; echo "${#_REPO_SET[@]}"; }

# unit_enabled UNIT / unit_enabled_global UNIT: the unit is enabled (system / for every user)
unit_enabled() { [ "$(systemctl is-enabled "$1" 2>/dev/null)" = enabled ]; }
unit_enabled_global() { [ "$(systemctl --global is-enabled "$1" 2>/dev/null)" = enabled ]; }
unit_exists() { systemctl cat "$1" >/dev/null 2>&1; }

sys_change() { SYS_CHANGES+=("$*"); }

# browser_field ID N: field N (2 label, 3 package, 4 desktop files) of browser ID
browser_field() { awk -F'|' -v id="$1" -v n="$2" '$1==id{print $n}' <<<"$BROWSERS"; }
browser_ids() { cut -d'|' -f1 <<<"$BROWSERS"; }
# browser_desktop ID: the first desktop file of browser ID that exists, else nothing
browser_desktop() {
    local f
    for f in $(browser_field "$1" 4); do
        [ -f "$SYS_ROOT/usr/share/applications/$f" ] && { echo "$f"; return 0; }
    done
    return 1
}
# browsers_installed: ids of the browsers in the table that are installed
browsers_installed() {
    local id
    while IFS= read -r id; do
        if pkg_installed "$(browser_field "$id" 3)" || browser_desktop "$id" >/dev/null; then echo "$id"; fi
    done < <(browser_ids)
}

# has_battery: a laptop (a battery in /sys/class/power_supply)
has_battery() {
    local t
    for t in "$SYS_ROOT"/sys/class/power_supply/*/type; do
        [ -r "$t" ] && [ "$(<"$t")" = Battery ] && return 0
    done
    return 1
}

_add_pkg() {   # _add_pkg NAME...: queue for the repositories or the AUR
    local p
    for p in "$@"; do
        [ -n "$p" ] || continue
        [[ " ${PKG_REPO[*]} ${PKG_AUR[*]} " == *" $p "* ]] && continue
        if in_repos "$p"; then PKG_REPO+=("$p")
        elif pkg_installed "$p"; then continue
        else PKG_AUR+=("$p"); fi
    done
}

# arch_plan BROWSER_ID WANT_GREETD: fills PKG_REPO, PKG_AUR, PKG_REMOVE, ARCH_NOTES. Uses the GPU plan
# (gpu_plan must have run) and the dependency check (check_deps must have run).
arch_plan() {
    local browser="$1" greetd="$2" id check level a rest p
    PKG_REPO=() PKG_AUR=() PKG_REMOVE=() ARCH_NOTES=()
    if [ "$(repo_set_size)" = 0 ]; then
        ARCH_NOTES+=("pacman knows no repository packages yet (no sync database): every package is assumed to be in the repositories")
        _repo_loaded=2
        in_repos() { true; }
    fi
    local keep_ppd=1
    for p in "${ARCH_POWER_ALTERNATIVES[@]}"; do pkg_installed "$p" && { keep_ppd=0; ARCH_NOTES+=("$p is installed: power-profiles-daemon is not added (the power profile switch stays hidden)"); break; }; done
    for p in "${ARCH_BASE_PKGS[@]}"; do
        [ "$p" = power-profiles-daemon ] && [ "$keep_ppd" = 0 ] && continue
        _add_pkg "$p"
    done
    # Dependency table rows whose check fails (alternatives such as the file manager count when present)
    while IFS='|' read -r id check level a rest; do
        [ -n "$id" ] || continue
        [ "$id" = power-profiles ] && [ "$keep_ppd" = 0 ] && continue
        _dep_has "$check" && continue
        for p in $a; do is_dm_package "$p" || _add_pkg "$p"; done
    done <<< "$DEPS_TABLE"
    _add_pkg "${GPU_PKGS[@]}"
    [ "${#GPU_AUR[@]}" = 0 ] || PKG_AUR+=("${GPU_AUR[@]}")
    [ "$greetd" = 1 ] && _add_pkg greetd
    if [ -n "$browser" ] && [ "$browser" != none ]; then _add_pkg "$(browser_field "$browser" 3)"; fi
    for p in "${ARCH_AUDIO_CONFLICTS[@]}"; do pkg_installed "$p" && PKG_REMOVE+=("$p"); done
    [ "${#PKG_REMOVE[@]}" = 0 ] || ARCH_NOTES+=("replaced by PipeWire: ${PKG_REMOVE[*]}")
    if pkg_installed jack2; then ARCH_NOTES+=("jack2 is installed and kept (pipewire-jack is not installed)"); fi
    if [ "${#PKG_AUR[@]}" -gt 0 ] && ! aur_helper >/dev/null; then
        _add_pkg base-devel git
        ARCH_NOTES+=("no AUR helper found: yay is built from the AUR first (as you, not as root)")
    fi
    return 0
}

# aur_helper: prints yay or paru when one is installed
aur_helper() {
    local h
    for h in yay paru; do command -v "$h" >/dev/null 2>&1 && { echo "$h"; return 0; }; done
    return 1
}

# keyrings: the distribution keyrings that are installed (refreshed before the upgrade)
_keyrings() {
    local k out=(archlinux-keyring)
    for k in cachyos-keyring endeavouros-keyring manjaro-keyring chaotic-keyring; do pkg_installed "$k" && out+=("$k"); done
    echo "${out[*]}"
}

# arch_install_packages: keyring, conflicts, full upgrade with the planned packages. Fatal on failure.
arch_install_packages() {
    # shellcheck disable=SC2046
    priv pacman -Sy --needed --noconfirm $(_keyrings) || die "refreshing the package keyring failed (network? mirrors?). Nothing else was changed."
    sys_change "packages: keyring refreshed"
    if [ "${#PKG_REMOVE[@]}" -gt 0 ]; then
        priv pacman -Rdd --noconfirm "${PKG_REMOVE[@]}" || die "removing ${PKG_REMOVE[*]} failed"
        sys_change "packages removed (replaced by PipeWire): ${PKG_REMOVE[*]}"
    fi
    priv pacman -Syu --needed --noconfirm "${PKG_REPO[@]}" || die "pacman failed: see the messages above. Re-run ./install.sh when it is fixed (nothing is installed twice)."
    sys_change "packages installed (repositories): ${PKG_REPO[*]}"
    pkg_installed_reset
    hash -r
    unset _DEP_FONTS
    ok "system up to date, ${#PKG_REPO[@]} packages checked"
}

# arch_install_aur: AUR packages as the user. Builds yay-bin first when no helper is installed.
# Failures are warnings: the rest of the desktop is still installed.
arch_install_aur() {
    [ "${#PKG_AUR[@]}" -gt 0 ] || return 0
    local h
    if ! h="$(aur_helper)"; then
        if [ "$DRY" = 1 ]; then
            say "  ${C_Y}would${C_0} build yay-bin from https://aur.archlinux.org/yay-bin.git (git clone + makepkg -si)"
            h=yay
        else
            local d="$TMP/yay-bin"
            if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$d" && (cd "$d" && makepkg -si --noconfirm); then
                hash -r; h=yay; ok "yay installed"; sys_change "packages installed (AUR helper): yay-bin"
            else
                warn "could not build yay: install these from the AUR yourself: ${PKG_AUR[*]}"; return 0
            fi
        fi
    fi
    local cmd=("$h" -S --needed --noconfirm)
    case "$h" in yay) cmd+=(--answerdiff None --answerclean None) ;; paru) cmd+=(--skipreview) ;; esac
    if [ "$DRY" = 1 ]; then say "  ${C_Y}would run${C_0} ${cmd[*]} ${PKG_AUR[*]}"; return 0; fi
    if "${cmd[@]}" "${PKG_AUR[@]}"; then ok "AUR: ${PKG_AUR[*]}"; sys_change "packages installed (AUR): ${PKG_AUR[*]}"
    else warn "$h could not install: ${PKG_AUR[*]} (try: $h -S ${PKG_AUR[*]})"; fi
    pkg_installed_reset
    hash -r
}

# arch_gpu_apply: NVIDIA modprobe options, initramfs, suspend services
NV_MODPROBE=/etc/modprobe.d/sleek-shell-nvidia.conf
arch_gpu_apply() {
    if [ "$GPU_PROPRIETARY" != 1 ]; then ok "graphics: ${GPU_KIND} (Mesa)"; return 0; fi
    local lines
    lines="$(gpu_modprobe_lines)"
    if [ -n "$lines" ]; then
        printf '# Written by Sleek Shell install.sh: kernel mode setting and video memory kept across suspend.\n%s\n' "$lines" \
            | priv_write "$NV_MODPROBE" 644 || die "cannot write $NV_MODPROBE"
        sys_change "file written: $NV_MODPROBE"
        if command -v mkinitcpio >/dev/null 2>&1; then priv mkinitcpio -P || warn "mkinitcpio -P failed: run it yourself before rebooting"
        elif command -v dracut >/dev/null 2>&1; then priv dracut --regenerate-all --force || warn "dracut failed: run dracut --regenerate-all --force yourself"
        else warn "no mkinitcpio or dracut found: regenerate your initramfs yourself so $NV_MODPROBE applies at boot"; fi
        ok "NVIDIA: $(tr '\n' ';' <<<"$lines" | sed 's/;$//; s/;/; /g')"
    else
        ok "NVIDIA: kernel mode setting and suspend options already configured"
    fi
    local u
    for u in nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service; do
        unit_exists "$u" || [ "$DRY" = 1 ] || continue
        unit_enabled "$u" && continue
        if priv systemctl enable "$u"; then sys_change "service enabled: $u"; else warn "could not enable $u: suspend may lose the picture"; fi
    done
    return 0
}

# arch_services: audio (PipeWire user units), network, Bluetooth, power profiles, NVIDIA suspend
arch_services() {
    local u missing=()
    for u in pipewire.socket pipewire-pulse.socket wireplumber.service; do unit_enabled_global "$u" || missing+=("$u"); done
    if [ "${#missing[@]}" -gt 0 ]; then
        if priv systemctl --global enable "${missing[@]}"; then sys_change "user services enabled for every user: ${missing[*]}"
        else warn "could not enable ${missing[*]} for every user: run systemctl --user enable --now ${missing[*]}"; fi
    fi
    ok "audio: PipeWire + WirePlumber (user services)"

    arch_network

    if unit_enabled bluetooth.service; then ok "bluetooth.service already enabled"
    elif priv systemctl enable --now bluetooth.service; then sys_change "service enabled: bluetooth.service"; ok "bluetooth.service enabled"
    else warn "could not enable bluetooth.service"; fi

    if pkg_installed power-profiles-daemon || { [ "$DRY" = 1 ] && [[ " ${PKG_REPO[*]} " == *" power-profiles-daemon "* ]]; }; then
        if unit_enabled power-profiles-daemon.service; then ok "power-profiles-daemon already enabled"
        elif priv systemctl enable --now power-profiles-daemon.service; then sys_change "service enabled: power-profiles-daemon.service"; ok "power-profiles-daemon enabled"
        else warn "could not enable power-profiles-daemon.service"; fi
    fi
    return 0
}

# arch_network: NetworkManager. Another network manager that is enabled is disabled (not stopped), and
# NetworkManager is only started now when nothing else manages the network: the connection you install
# over keeps working until the reboot.
arch_network() {
    local u others=()
    if unit_enabled NetworkManager.service; then ok "NetworkManager already enabled"
    else
        for u in systemd-networkd.service dhcpcd.service connman.service wicd.service; do unit_enabled "$u" && others+=("$u"); done
        while IFS= read -r u; do [ -n "$u" ] && others+=("$u"); done < <(systemctl list-unit-files --state=enabled --no-legend 'netctl*' 2>/dev/null | awk '{print $1}')
        if [ "${#others[@]}" -gt 0 ]; then
            if priv systemctl enable NetworkManager.service; then
                sys_change "service enabled: NetworkManager.service"
                if priv systemctl disable "${others[@]}"; then sys_change "services disabled (NetworkManager replaces them): ${others[*]}"
                else warn "could not disable ${others[*]}: they may fight NetworkManager over the network"; fi
                ok "NetworkManager enabled; it takes over from ${others[*]} after the reboot"
            else
                warn "could not enable NetworkManager.service: ${others[*]} kept"
            fi
        elif priv systemctl enable --now NetworkManager.service; then
            sys_change "service enabled: NetworkManager.service"; ok "NetworkManager enabled"
        else
            warn "could not enable NetworkManager.service"
        fi
    fi
    if unit_enabled iwd.service && ! grep -rqs 'wifi.backend' "$SYS_ROOT/etc/NetworkManager/conf.d"; then
        printf '# Written by Sleek Shell install.sh: iwd was already managing Wi-Fi, NetworkManager uses it.\n[device]\nwifi.backend=iwd\n' \
            | priv_write /etc/NetworkManager/conf.d/sleek-shell-iwd.conf 644 || { warn "could not write the iwd backend setting for NetworkManager"; return 0; }
        sys_change "file written: /etc/NetworkManager/conf.d/sleek-shell-iwd.conf"
        ok "iwd stays enabled; NetworkManager uses it as its Wi-Fi backend"
    fi
    return 0
}

# login_shell: the user's login shell from the passwd database
login_shell() { getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7; }

# arch_login_shell: zsh as login shell, only when it is still bash (a shell you picked yourself is kept)
arch_login_shell() {
    local cur zsh_path
    cur="$(login_shell)"
    case "$cur" in
        */zsh) ok "login shell: zsh"; return 0 ;;
        /bin/bash|/usr/bin/bash|"") ;;
        *) ok "login shell: $cur (kept)"; return 0 ;;
    esac
    zsh_path="$(command -v zsh 2>/dev/null || echo /usr/bin/zsh)"
    if priv usermod -s "$zsh_path" "$(id -un)"; then
        sys_change "login shell: ${cur:-unset} -> $zsh_path (undo: sudo usermod -s ${cur:-/bin/bash} $(id -un))"; ok "login shell: zsh (from the next login)"
    else
        warn "could not change the login shell to zsh (try: chsh -s $zsh_path)"
    fi
    return 0
}

# ------------------------------------------------------------------------------------- greeter
# greeter_decide CHOICE (auto|sleek|keep): sets GREETER_ACTION and GREETER_OLD from the current display
# manager. GREETER_ACTION: install (no login screen yet: install + enable), refresh (greetd already runs
# the Sleek greeter), replace (switch from GREETER_OLD), keep (leave the login screen alone).
GREETER_ACTION=keep
GREETER_OLD=""
greeter_decide() {
    local choice="$1" dm
    dm="$(display_manager)"
    GREETER_OLD=""
    if [ "$dm" = greetd ] && [ "$(greetd_uses_sleek)" = yes ]; then
        GREETER_ACTION=refresh; [ "$choice" = keep ] && GREETER_ACTION=keep; return 0
    fi
    if [ "$dm" = none ]; then
        case "$choice" in keep) GREETER_ACTION=keep ;; *) GREETER_ACTION=install ;; esac
        return 0
    fi
    GREETER_OLD="$dm"
    case "$choice" in
        sleek) GREETER_ACTION=replace ;;
        keep) GREETER_ACTION=keep ;;
        auto)
            if choose_yesno "Replace the current login screen ($dm) with the Sleek Shell greeter?" no; then
                GREETER_ACTION=replace
            else
                GREETER_ACTION=keep
            fi ;;
    esac
}

# arch_greeter: run the greeter installer (the copy installed under ~/.local/share/sleek-shell) as root
arch_greeter() {
    local g="$DATA/greeter/install.sh"
    case "$GREETER_ACTION" in
        keep) ok "login screen: $(display_manager) (kept)"; return 0 ;;
    esac
    [ "$DRY" = 1 ] || [ -x "$g" ] || { warn "greeter installer not found at $g: skipped"; return 0; }
    if [ "$GREETER_ACTION" = replace ] && [ -n "$GREETER_OLD" ] && [ "$GREETER_OLD" != greetd ]; then
        priv systemctl disable "$GREETER_OLD.service" || { warn "could not disable $GREETER_OLD: login screen kept"; return 0; }
        sys_change "display manager disabled: $GREETER_OLD.service (undo: sudo systemctl disable greetd && sudo systemctl enable $GREETER_OLD)"
    fi
    if ! priv bash "$g" install; then
        warn "the greeter installer failed: your login screen is unchanged (details above; retry: sudo $g)"
        return 0
    fi
    [ "$GREETER_ACTION" = refresh ] && { ok "login screen: Sleek Shell greeter (refreshed)"; return 0; }
    if priv bash "$g" --enable --yes --replace; then
        sys_change "login screen: Sleek Shell greeter (greetd) from the next boot (undo: sudo $DATA/greeter/uninstall.sh)"
        ok "login screen: Sleek Shell greeter from the next boot"
    else
        warn "the greeter could not be enabled (details above); retry: sudo $g --enable"
    fi
}

# --------------------------------------------------------------------------------------- idle
IDLE_LOCK_CHOICES="0 1 2 5 10 15 30"
IDLE_OFF_CHOICES="0 1 2 5 10 15 30"
IDLE_SUSPEND_CHOICES="0 15 30 60 120"
# idle_current KEY DEFAULT: the value in settings.json, else DEFAULT
idle_current() {
    local f="$CFG/sleek-shell/settings.json" v=""
    if [ -f "$f" ] && command -v python3 >/dev/null 2>&1; then
        v="$(python3 -c 'import json,sys
try:
    v=json.load(open(sys.argv[1])).get(sys.argv[2])
    print(int(v) if isinstance(v,bool) else v if isinstance(v,int) else "")
except Exception: print("")' "$f" "$1" 2>/dev/null)"
    fi
    echo "${v:-$2}"
}
idle_valid() { [[ " $2 " == *" $1 "* ]]; }

# apply_idle LOCK OFF SUSPEND [BATTERY_SEPARATE [BLOCK BOFF BSUSPEND]]: merge the timeouts (minutes, 0 = never)
# into settings.json. BATTERY_SEPARATE is 1, 0 or empty (unchanged); the battery set is written when given.
apply_idle() {
    local f="$CFG/sleek-shell/settings.json" btxt=""
    [ -z "${7:-}" ] || btxt=", on battery $5/$6/$7 min"
    [ "${4:-}" != 0 ] || btxt=", no separate battery timeouts"
    if [ "$DRY" = 1 ]; then say "  ${C_Y}would set${C_0} lock after $1 min, screen off after $2 min, suspend after $3 min$btxt in ${f/#$HOME/\~}"; return 0; fi
    command -v python3 >/dev/null 2>&1 || { warn "python3 missing: idle settings not written"; return 0; }
    mkdir -p "$(dirname "$f")"
    python3 - "$f" "$1" "$2" "$3" "${4:-}" "${5:-}" "${6:-}" "${7:-}" <<'PY' || { warn "could not update $f (is it valid JSON?): idle settings unchanged"; return 0; }
import json, os, sys, tempfile
path, lock, off, sus = sys.argv[1], *map(int, sys.argv[2:5])
sep, bat = sys.argv[5], sys.argv[6:9]
data = {}
if os.path.exists(path):
    with open(path) as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        raise SystemExit(1)
data.update({"idleLockMin": lock, "idleScreenOffMin": off, "idleSuspendMin": sus})
if sep:
    data["idleBatterySeparate"] = sep == "1"
if all(bat):
    data.update(dict(zip(("idleBatteryLockMin", "idleBatteryScreenOffMin", "idleBatterySuspendMin"), map(int, bat))))
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".settings.")
with os.fdopen(fd, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
os.replace(tmp, path)
PY
    ok "idle: lock $( [ "$1" = 0 ] && echo never || echo "after $1 min"), screen off $( [ "$2" = 0 ] && echo never || echo "after $2 min"), suspend $( [ "$3" = 0 ] && echo never || echo "after $3 min")$btxt"
}

# ------------------------------------------------------------------------------------ browser
# default_browser: the desktop file that handles https for the user (xdg-mime), or nothing
default_browser() { command -v xdg-mime >/dev/null 2>&1 && xdg-mime query default x-scheme-handler/https 2>/dev/null; }

# apply_browser ID EXPLICIT: make browser ID the default (EXPLICIT=1: chosen by you, else only when unset)
apply_browser() {
    local id="$1" explicit="$2" desk cur
    [ -n "$id" ] && [ "$id" != none ] || return 0
    cur="$(default_browser || true)"
    if [ "$DRY" = 1 ]; then
        if [ "$explicit" = 1 ] || [ -z "$cur" ]; then say "  ${C_Y}would set${C_0} $(browser_field "$id" 2) as the default browser"; fi
        return 0
    fi
    if ! desk="$(browser_desktop "$id")"; then
        warn "$(browser_field "$id" 2): none of $(browser_field "$id" 4) found in /usr/share/applications; default browser not set"
        return 0
    fi
    if [ -n "$cur" ] && [ "$explicit" != 1 ]; then ok "default browser: $cur (kept)"; return 0; fi
    xdg-mime default "$desk" x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml \
        && ok "default browser: $(browser_field "$id" 2) ($desk)" \
        || warn "xdg-mime could not set $desk as the default browser"
}

# --------------------------------------------------------------------------------------- verify
VERIFY_LINES=()
VERIFY_FAILED=0
_v() {   # _v NAME CMD...: one verification line
    local n="$1"; shift
    if "$@" >/dev/null 2>&1; then VERIFY_LINES+=("ok    $n"); ok "$n"
    else VERIFY_LINES+=("FAIL  $n"); VERIFY_FAILED=$((VERIFY_FAILED + 1)); warn "check failed: $n"; fi
}
_pkgs_present() { local p; for p in "$@"; do pacman -Q "$p" >/dev/null 2>&1 || return 1; done; }
_global_units() { local u; for u in "$@"; do unit_enabled_global "$u" || return 1; done; }

# arch_verify: what a working desktop needs after the reboot
arch_verify() {
    VERIFY_LINES=() VERIFY_FAILED=0
    _v "repository packages installed (${#PKG_REPO[@]})" _pkgs_present "${PKG_REPO[@]}"
    [ "${#PKG_AUR[@]}" = 0 ] || _v "AUR packages installed: ${PKG_AUR[*]}" _pkgs_present "${PKG_AUR[@]}"
    _v "Hyprland and Quickshell found" sh -c 'command -v Hyprland && { command -v quickshell || command -v qs; }'
    _v "PipeWire user services enabled" _global_units pipewire.socket pipewire-pulse.socket wireplumber.service
    _v "NetworkManager enabled" unit_enabled NetworkManager.service
    _v "bluetooth.service enabled" unit_enabled bluetooth.service
    pkg_installed power-profiles-daemon && _v "power-profiles-daemon enabled" unit_enabled power-profiles-daemon.service
    _v "JetBrainsMono Nerd Font installed" sh -c 'fc-list : family | grep -qi "JetBrainsMono Nerd Font"'
    if [ "$GPU_PROPRIETARY" = 1 ]; then
        _v "NVIDIA kernel mode setting configured" sh -c '[ -z "$1" ]' _ "$(gpu_modprobe_lines)"
        unit_exists nvidia-suspend.service && _v "NVIDIA suspend services enabled" sh -c 'for u in nvidia-suspend nvidia-resume; do [ "$(systemctl is-enabled $u.service 2>/dev/null)" = enabled ] || exit 1; done'
    fi
    if [ "$KEEP_SHELL" = 0 ]; then
        case "$(login_shell)" in */bash|/bin/sh|/usr/bin/sh|"") VERIFY_LINES+=("note  login shell kept: $(login_shell)") ;; *) _v "login shell: $(login_shell)" true ;; esac
    fi
    case "$GREETER_ACTION" in
        install|replace|refresh)
            _v "login screen: greetd enabled with the Sleek Shell greeter" sh -c '[ "$(systemctl is-enabled greetd.service 2>/dev/null)" = enabled ] && grep -qs sleek-shell "$1/etc/greetd/config.toml"' _ "$SYS_ROOT" ;;
    esac
    return 0
}
