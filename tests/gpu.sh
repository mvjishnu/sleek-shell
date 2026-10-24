#!/usr/bin/env bash
# lib/gpu.sh against fake /sys and /usr/lib/modules trees: driver choice per NVIDIA generation, hybrid
# laptops, kernels, an already installed driver, and the modprobe options. pacman is a stub.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
BIN="$TMPROOT/bin"; mkdir -p "$BIN"
printf '#!/bin/sh\n[ "$1" = -Qq ] && cat "$PKGS" 2>/dev/null\nexit 0\n' > "$BIN/pacman"
printf '#!/bin/sh\necho core; echo extra; [ -n "${MULTILIB:-}" ] && echo multilib\nexit 0\n' > "$BIN/pacman-conf"
chmod +x "$BIN"/*

# fx "VEN:DEV:DRIVER ..." "KERNEL ..." "INSTALLED PKGS": a fresh fake root; prints its path
fx() {
    local r g i=0 ven dev drv k
    r="$(mktemp -d "$TMPROOT/root.XXXXXX")"
    mkdir -p "$r/sys/bus/pci/devices" "$r/drivers"
    for g in $1; do
        IFS=: read -r ven dev drv <<<"$g"
        local d="$r/sys/bus/pci/devices/0000:0$i:00.0"; i=$((i + 1))
        mkdir -p "$d"; echo 0x030000 > "$d/class"; echo "0x$ven" > "$d/vendor"; echo "0x$dev" > "$d/device"
        [ "$drv" = none ] || { mkdir -p "$r/drivers/$drv"; ln -s "../../../../drivers/$drv" "$d/driver"; }
    done
    mkdir -p "$r/sys/bus/pci/devices/0000:0$i:1f.0"; echo 0x060100 > "$r/sys/bus/pci/devices/0000:0$i:1f.0/class"
    for k in $2; do mkdir -p "$r/usr/lib/modules/6.$i.$k"; echo "$k" > "$r/usr/lib/modules/6.$i.$k/pkgbase"; i=$((i + 1)); done
    printf '%s\n' $3 > "$r/pkgs"
    echo "$r"
}
# plan ROOT MODE CODE: gpu_scan + gpu_plan MODE, then CODE
plan() {
    SLEEK_SYS_ROOT="$1" PKGS="$1/pkgs" PATH="$BIN:$PATH" bash -c '
        . "$0/lib/common.sh"; . "$0/lib/distro.sh"; . "$0/lib/gpu.sh"; gpu_scan; gpu_plan "$1"; eval "$2"' "$REPO" "$2" "$3"
}
pk() { plan "$1" "$2" 'echo "${GPU_PKGS[*]}"'; }
aur() { plan "$1" "$2" 'echo "${GPU_AUR[*]}"'; }
kind() { plan "$1" "$2" 'echo "$GPU_KIND $GPU_NVIDIA_DRIVER $GPU_PROPRIETARY"'; }
has() { [[ " $1 " == *" $2 "* ]]; }

R="$(fx "8086:9a49:i915" linux "")"
check "intel: mesa + vulkan-intel + media driver" test "$(pk "$R" auto)" = "mesa vulkan-intel intel-media-driver"
check "intel: kind intel, no proprietary driver" test "$(kind "$R" auto)" = "intel  0"
R="$(fx "1002:15d8:amdgpu" linux "")"
check "amd: mesa + vulkan-radeon" test "$(pk "$R" auto)" = "mesa vulkan-radeon"
R="$(fx "1234:1111:bochs-drm" linux "")"
check "virtual machine: mesa only, kind vm" sh -c "[ '$(pk "$R" auto)' = mesa ] && [ '$(kind "$R" auto)' = 'vm  0' ]"
check "virtual machine: 3D acceleration note" grep -q '3D acceleration' <<<"$(plan "$R" auto 'printf "%s\n" "${GPU_NOTES[@]}"')"
R="$(fx "" linux "")"
check "no GPU: kind none" test "$(kind "$R" auto)" = "none  0"
check "describe without GPU" grep -q 'no display controller' <<<"$(plan "$R" auto gpu_describe)"

# Turing+ (TU117M, like the reference laptop) -> open modules
R="$(fx "1002:15d8:amdgpu 10de:1f91:nouveau" linux "")"
check "hybrid AMD + Turing: kind hybrid, open driver" test "$(kind "$R" auto)" = "hybrid open 1"
p="$(pk "$R" auto)"
check "stock kernel: nvidia-open (prebuilt), utils, VA-API, prime" sh -c "for x in nvidia-open nvidia-utils libva-nvidia-driver nvidia-prime vulkan-radeon; do case ' $p ' in *\" \$x \"*) ;; *) exit 1 ;; esac; done"
check "stock kernel: no dkms, no headers" sh -c "! grep -qE 'dkms|headers' <<<'$p'"
check "nouveau loaded now: note about the reboot" grep -q 'takes over after the reboot' <<<"$(plan "$R" auto 'printf "%s\n" "${GPU_NOTES[@]}"')"
check "describe names both GPUs" sh -c "out=\"\$(cat)\"; grep -q 'NVIDIA \[10de:1f91\], driver: nouveau' <<<\"\$out\" && grep -q 'AMD \[1002:15d8\]' <<<\"\$out\"" <<<"$(plan "$R" auto gpu_describe)"
R="$(fx "10de:2684:none" linux-lts "")"
check "lts kernel only: nvidia-open-lts" has "$(pk "$R" auto)" nvidia-open-lts
check "desktop NVIDIA only: kind nvidia, no prime" sh -c "[ '$(kind "$R" auto)' = 'nvidia open 1' ] && ! grep -q prime <<<'$(pk "$R" auto)'"
R="$(fx "10de:2684:none" "linux-cachyos linux-cachyos-lts" "")"
p="$(pk "$R" auto)"
check "custom kernels: nvidia-open-dkms + headers for each" sh -c "for x in nvidia-open-dkms linux-cachyos-headers linux-cachyos-lts-headers; do case ' $p ' in *\" \$x \"*) ;; *) exit 1 ;; esac; done"
R="$(fx "10de:2684:none" "linux linux-zen" "")"
check "two kernels: dkms + both headers" sh -c "p='$(pk "$R" auto)'; for x in nvidia-open-dkms linux-headers linux-zen-headers; do case \" \$p \" in *\" \$x \"*) ;; *) exit 1 ;; esac; done"
R="$(fx "10de:2684:none" "" "")"
check "no kernel found: note to install headers" grep -q 'install the headers' <<<"$(plan "$R" auto 'printf "%s\n" "${GPU_NOTES[@]}"')"

# Maxwell/Pascal/Volta -> 580xx from the AUR
R="$(fx "8086:3e9b:i915 10de:1c8d:none" linux "")"
check "Pascal (GTX 1050 mobile): 580xx" test "$(kind "$R" auto)" = "hybrid 580xx 1"
check "Pascal: driver from the AUR" test "$(aur "$R" auto)" = "nvidia-580xx-dkms nvidia-580xx-utils"
check "Pascal: headers, no nvidia-open" sh -c "p='$(pk "$R" auto)'; case \" \$p \" in *' linux-headers '*) ;; *) exit 1 ;; esac; ! grep -q nvidia-open <<<\"\$p\""
check "--nvidia=open on Pascal warns" grep -q 'Turing' <<<"$(plan "$R" open 'printf "%s\n" "${GPU_NOTES[@]}"')"
check "--nvidia=nouveau: no proprietary driver" sh -c "[ '$(kind "$R" nouveau)' = 'hybrid nouveau 0' ] && grep -q vulkan-nouveau <<<'$(pk "$R" nouveau)'"

# Kepler and older -> nouveau
R="$(fx "10de:0fc6:nouveau" linux "")"
check "Kepler: nouveau" test "$(kind "$R" auto)" = "nvidia nouveau 0"
check "Kepler: nothing from the AUR" test -z "$(aur "$R" auto)"

# An installed driver is kept
R="$(fx "10de:1f91:nvidia" linux "nvidia-580xx-dkms nvidia-580xx-utils")"
check "installed 580xx on a Turing card is kept" sh -c "[ '$(kind "$R" auto)' = 'nvidia existing 1' ] && [ -z '$(aur "$R" auto)' ] && ! grep -q nvidia-open <<<'$(pk "$R" auto)'"
R="$(fx "10de:1f91:nvidia" linux-cachyos "nvidia-open-dkms nvidia-utils")"
check "installed nvidia-open-dkms is kept (utils refreshed)" sh -c "p='$(pk "$R" auto)'; [ '$(kind "$R" auto)' = 'nvidia existing 1' ] && grep -q nvidia-utils <<<\"\$p\" && ! grep -q linux-cachyos-headers <<<\"\$p\""
R="$(fx "10de:1f91:nvidia" linux "linux-cachyos-nvidia-open")"
check "kernel-bundled NVIDIA module counts as installed" test "$(kind "$R" auto)" = "nvidia existing 1"
check "explicit --nvidia=open overrides the installed driver" test "$(kind "$R" open)" = "nvidia open 1"

# modprobe options
R="$(fx "10de:1f91:nvidia" linux "")"
check "modprobe: both options when nothing is configured" test "$(plan "$R" auto gpu_modprobe_lines | wc -l)" = 2
mkdir -p "$R/usr/lib/modprobe.d"; printf 'options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp\n' > "$R/usr/lib/modprobe.d/nvidia-sleep.conf"
check "modprobe: preserve option already set by the package" test "$(plan "$R" auto gpu_modprobe_lines)" = "options nvidia_drm modeset=1 fbdev=1"
mkdir -p "$R/proc"; echo 'root=UUID=x rw nvidia_drm.modeset=1' > "$R/proc/cmdline"
check "modprobe: modeset on the kernel command line counts" test -z "$(plan "$R" auto gpu_modprobe_lines)"
check "modprobe: nothing for Mesa systems" test -z "$(plan "$(fx "1002:15d8:amdgpu" linux "")" auto gpu_modprobe_lines)"
check "multilib detection" sh -c "MULTILIB=1 PATH='$BIN:$PATH' bash -c '. \"$REPO/lib/common.sh\"; . \"$REPO/lib/distro.sh\"; . \"$REPO/lib/gpu.sh\"; multilib_enabled' && ! PATH='$BIN:$PATH' bash -c '. \"$REPO/lib/common.sh\"; . \"$REPO/lib/distro.sh\"; . \"$REPO/lib/gpu.sh\"; multilib_enabled'"

finish
