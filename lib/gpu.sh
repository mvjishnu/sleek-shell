# shellcheck shell=bash
# GPU detection and the driver plan for Arch. Read-only: install.sh applies the plan.
#
# Sources: /sys/bus/pci/devices/*/{class,vendor,device,driver}, /usr/lib/modules/*/pkgbase (installed
# kernels), the installed package list (pacman -Qq) and the enabled repositories (pacman-conf).
# Test hook: SYS_ROOT (from lib/distro.sh) prefixes /sys and /usr/lib/modules; pacman is stubbed on PATH.
#
# NVIDIA generations (PCI device id, see https://wiki.archlinux.org/title/NVIDIA):
#   >= 0x1e00   Turing and newer   nvidia-open (linux), nvidia-open-lts (linux-lts), else nvidia-open-dkms
#   0x1300..    Maxwell .. Volta   nvidia-580xx-dkms + nvidia-580xx-utils (AUR, the last driver for them)
#   <  0x1300   Kepler and older   nouveau (open source, in mesa); the 470xx driver does not support Wayland well

GPU_LIST=()            # "vendor:device:driver:pci-slot", e.g. 10de:1f91:nvidia:0000:01:00.0
GPU_KIND=none          # none | amd | intel | nvidia | hybrid | vm
GPU_HYBRID=0           # an NVIDIA card next to another display GPU (laptop with an iGPU)
GPU_NVIDIA_DEV=""      # device id of the first NVIDIA card
GPU_NVIDIA_DRIVER=""   # open | 580xx | nouveau | existing | "" (no NVIDIA card)
GPU_PROPRIETARY=0      # the NVIDIA kernel driver is (or will be) in use: modeset + suspend services
GPU_PKGS=()            # repository packages
GPU_AUR=()             # AUR packages
GPU_NOTES=()
GPU_KERNELS=()         # installed kernel package names (pkgbase)

declare -A _PKG_Q=()
_pkg_q_loaded=0
# pkg_installed NAME: the package is installed (pacman -Qq, read once)
pkg_installed() {
    if [ "$_pkg_q_loaded" = 0 ]; then
        local p
        while IFS= read -r p; do [ -n "$p" ] && _PKG_Q["$p"]=1; done < <(pacman -Qq 2>/dev/null)
        _pkg_q_loaded=1
    fi
    [ -n "${_PKG_Q[$1]+x}" ]
}
pkg_installed_reset() { _PKG_Q=(); _pkg_q_loaded=0; }
# pkg_installed_matching REGEX: installed package names matching an extended regex
pkg_installed_matching() { pkg_installed __load__ || true; printf '%s\n' "${!_PKG_Q[@]}" | grep -E -- "$1" | sort; }

multilib_enabled() { pacman-conf --repo-list 2>/dev/null | grep -qx multilib; }

gpu_scan() {
    local d cls ven dev drv
    GPU_LIST=()
    for d in "$SYS_ROOT"/sys/bus/pci/devices/*; do
        [ -r "$d/class" ] || continue
        cls="$(<"$d/class")"
        case "$cls" in 0x03*) ;; *) continue ;; esac
        ven="$(<"$d/vendor")"; dev="$(<"$d/device")"
        drv=none
        [ -L "$d/driver" ] && drv="$(basename "$(readlink "$d/driver")")"
        GPU_LIST+=("${ven#0x}:${dev#0x}:$drv:${d##*/}")
    done
    GPU_KERNELS=()
    local f k
    for f in "$SYS_ROOT"/usr/lib/modules/*/pkgbase; do
        [ -r "$f" ] || continue
        k="$(<"$f")"
        [[ " ${GPU_KERNELS[*]} " == *" $k "* ]] || GPU_KERNELS+=("$k")
    done
    return 0
}

# gpu_describe: one line per GPU for the report
gpu_describe() {
    local e ven dev drv name
    [ "${#GPU_LIST[@]}" -gt 0 ] || { echo "no display controller found"; return; }
    for e in "${GPU_LIST[@]}"; do
        IFS=: read -r ven dev drv _ <<<"$e"
        case "$ven" in
            10de) name=NVIDIA ;; 1002) name=AMD ;; 8086) name=Intel ;;
            1af4|1b36|1234) name="virtual (QEMU/virtio)" ;; 15ad) name="virtual (VMware)" ;; 80ee) name="virtual (VirtualBox)" ;;
            1414) name="virtual (Hyper-V)" ;; *) name="vendor $ven" ;;
        esac
        printf '%s [%s:%s], driver: %s\n' "$name" "$ven" "$dev" "$drv"
    done
}

# _nv_existing: prints the NVIDIA driver family that is already installed (modern | 580xx | 470xx | "")
_nv_existing() {
    if [ -n "$(pkg_installed_matching '^nvidia-580xx-(dkms|utils)$')" ]; then echo 580xx
    elif [ -n "$(pkg_installed_matching '^nvidia-470xx-(dkms|utils)$')" ]; then echo 470xx
    elif [ -n "$(pkg_installed_matching '^(nvidia-open(-dkms|-lts)?|nvidia(-dkms|-lts)?|linux.*-nvidia(-open)?)$')" ]; then echo modern
    fi
}

_headers_for_kernels() {
    local k
    for k in "${GPU_KERNELS[@]}"; do GPU_PKGS+=("$k-headers"); done
    [ "${#GPU_KERNELS[@]}" -gt 0 ] || GPU_NOTES+=("no installed kernel found under /usr/lib/modules: install the headers for your kernel yourself")
}

# gpu_plan [auto|open|580xx|nouveau]: fills GPU_KIND, GPU_PKGS, GPU_AUR, GPU_NOTES ... from GPU_LIST
gpu_plan() {
    local want="${1:-auto}" e ven dev drv nv=0 amd=0 intel=0 vm=0 nvdrv=""
    GPU_PKGS=(mesa) GPU_AUR=() GPU_NOTES=() GPU_HYBRID=0 GPU_NVIDIA_DEV="" GPU_NVIDIA_DRIVER="" GPU_PROPRIETARY=0
    for e in "${GPU_LIST[@]}"; do
        IFS=: read -r ven dev drv _ <<<"$e"
        case "$ven" in
            10de) nv=1; [ -n "$GPU_NVIDIA_DEV" ] || { GPU_NVIDIA_DEV="$dev"; nvdrv="$drv"; } ;;
            1002) amd=1 ;;
            8086) intel=1 ;;
            1af4|1b36|1234|15ad|80ee|1414|1013) vm=1 ;;
        esac
    done
    [ "$amd" = 1 ] && GPU_PKGS+=(vulkan-radeon)
    [ "$intel" = 1 ] && GPU_PKGS+=(vulkan-intel intel-media-driver)
    if [ "$vm" = 1 ] && [ "$nv$amd$intel" = 000 ]; then
        GPU_KIND=vm
        GPU_NOTES+=("virtual machine: Mesa only. Enable 3D acceleration in the VM settings, or Hyprland will be slow or fail to start")
        return 0
    fi
    if [ "$nv" = 0 ]; then
        if [ "$amd" = 1 ] && [ "$intel" = 1 ]; then GPU_KIND=hybrid
        elif [ "$amd" = 1 ]; then GPU_KIND=amd
        elif [ "$intel" = 1 ]; then GPU_KIND=intel
        else GPU_KIND=none; GPU_NOTES+=("no GPU found: Mesa is installed; Hyprland needs a working DRM/KMS driver"); fi
        return 0
    fi

    GPU_KIND=nvidia
    [ "$((amd + intel + vm))" -gt 0 ] && { GPU_KIND=hybrid; GPU_HYBRID=1; }
    local id=$((16#$GPU_NVIDIA_DEV)) existing
    existing="$(_nv_existing)"
    if [ "$want" = auto ]; then
        if [ -n "$existing" ]; then want=existing
        elif [ "$id" -lt $((16#1300)) ]; then want=nouveau
        elif [ "$id" -lt $((16#1e00)) ]; then want=580xx
        else want=open; fi
    fi
    if [ "$want" = open ] && [ "$id" -lt $((16#1e00)) ]; then
        GPU_NOTES+=("--nvidia=open: the open kernel modules need a Turing (GTX 16xx / RTX) or newer card; this one is older and will not work with them")
    fi
    GPU_NVIDIA_DRIVER="$want"
    case "$want" in
        existing)
            GPU_PROPRIETARY=1
            case "$existing" in
                580xx) GPU_NOTES+=("keeping the installed nvidia-580xx driver") ;;
                470xx) GPU_NOTES+=("keeping the installed nvidia-470xx driver (Wayland support on it is limited)") ;;
                *) GPU_PKGS+=(nvidia-utils libva-nvidia-driver); GPU_NOTES+=("keeping the installed NVIDIA kernel driver package") ;;
            esac ;;
        open)
            GPU_PROPRIETARY=1
            if [ "${#GPU_KERNELS[@]}" = 1 ] && [ "${GPU_KERNELS[0]}" = linux ]; then GPU_PKGS+=(nvidia-open)
            elif [ "${#GPU_KERNELS[@]}" = 1 ] && [ "${GPU_KERNELS[0]}" = linux-lts ]; then GPU_PKGS+=(nvidia-open-lts)
            else GPU_PKGS+=(nvidia-open-dkms); _headers_for_kernels; fi
            GPU_PKGS+=(nvidia-utils libva-nvidia-driver) ;;
        580xx)
            GPU_PROPRIETARY=1
            GPU_AUR+=(nvidia-580xx-dkms nvidia-580xx-utils)
            GPU_PKGS+=(libva-nvidia-driver)
            _headers_for_kernels
            GPU_NOTES+=("this card (Maxwell/Pascal/Volta) needs the legacy nvidia-580xx driver from the AUR") ;;
        nouveau)
            GPU_PKGS+=(vulkan-nouveau)
            [ "$id" -lt $((16#1300)) ] && GPU_NOTES+=("this card is older than Maxwell: the open source nouveau driver is used (no proprietary driver supports it on Wayland)") ;;
        *) die "unknown --nvidia value '$want' (open, 580xx or nouveau)" ;;
    esac
    if [ "$GPU_HYBRID" = 1 ] && [ "$GPU_PROPRIETARY" = 1 ]; then
        GPU_PKGS+=(nvidia-prime)
        GPU_NOTES+=("hybrid graphics: the desktop runs on the integrated GPU; start a program on the NVIDIA GPU with: prime-run <program>")
    fi
    [ "$nvdrv" = nouveau ] && [ "$GPU_PROPRIETARY" = 1 ] && GPU_NOTES+=("nouveau is loaded now: the NVIDIA driver takes over after the reboot")
    return 0
}

# gpu_modprobe_needed: the NVIDIA modprobe options Sleek Shell would add (empty when already configured)
gpu_modprobe_lines() {
    [ "$GPU_PROPRIETARY" = 1 ] || return 0
    local dirs=("$SYS_ROOT/etc/modprobe.d" "$SYS_ROOT/usr/lib/modprobe.d" "$SYS_ROOT/run/modprobe.d")
    local cmdline=""; [ -r "$SYS_ROOT/proc/cmdline" ] && cmdline="$(<"$SYS_ROOT/proc/cmdline")"
    if ! grep -rqsE '^[[:space:]]*options[[:space:]]+nvidia[_-]drm[[:space:]].*modeset=' "${dirs[@]}" && [[ "$cmdline" != *nvidia_drm.modeset=* ]] && [[ "$cmdline" != *nvidia-drm.modeset=* ]]; then
        echo "options nvidia_drm modeset=1 fbdev=1"
    fi
    if ! grep -rqsE '^[[:space:]]*options[[:space:]]+nvidia[[:space:]].*NVreg_PreserveVideoMemoryAllocations=' "${dirs[@]}" && [[ "$cmdline" != *NVreg_PreserveVideoMemoryAllocations* ]]; then
        echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1"
    fi
}
