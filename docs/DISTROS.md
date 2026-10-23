# Distribution support

| Family | Detected from `ID`/`ID_LIKE` | Status |
|---|---|---|
| Arch | arch, cachyos, endeavouros, manjaro, garuda, artix, … | **Supported**: developed and used daily on CachyOS |
| Fedora | fedora, nobara, ultramarine, bazzite, rhel, … | Experimental: untested on real hardware |
| openSUSE | opensuse-tumbleweed, opensuse-leap, sles | Experimental: untested; Tumbleweed only |
| Debian/Ubuntu | debian, ubuntu, linuxmint, pop, … | Experimental: untested; no packaged Hyprland new enough |
| Anything else | NixOS, Gentoo, Void, Alpine, … | Unsupported: may work if you provide the dependencies |

"Experimental" means the installer detects the distro and prints the right package-manager command. The package names
in `lib/deps.sh` are best effort. **Nobody has installed Sleek Shell on these distributions yet.** Detection and
package hints are tested only against the os-release fixtures in `tests/fixtures/os-release/` (`tests/distro.sh`).
Reports and fixes are welcome; see [CONTRIBUTING.md](../CONTRIBUTING.md).

`./install.sh --check` works everywhere. It shows what is missing and the command to install it, and it installs nothing.

## The hard requirements

On every distribution, these are the hard part:
- **Hyprland 0.55 or newer.** The config uses Hyprland's Lua API (`hl.*`), and older versions cannot read it.
- **Quickshell 0.2 or newer** (tested with 0.3.2). The greeter needs Quickshell 0.3+ built with the Greetd service.
- **awww**, the wallpaper daemon (the successor of swww).
- **rofi 2.0 or newer**, for native Wayland support.

## Arch and derivatives
Everything is in the official repositories (`extra`) except where your derivative adds its own:
```sh
sudo pacman -S --needed hyprland quickshell python awww wl-clipboard cliphist rofi fontconfig xdg-utils \
    ttf-jetbrains-mono-nerd wireplumber networkmanager libnotify jq grim slurp kitty inter-font
```

## Fedora
- Hyprland: COPR `solopasha/hyprland`. Check that it ships 0.55 or newer.
- Quickshell: COPR `errornointernet/quickshell`.
- Not packaged: awww and the JetBrains Mono Nerd Font. Build awww from source, and put the font in `~/.local/share/fonts`.
- rofi: install `rofi-wayland`.

## openSUSE Tumbleweed
- Hyprland is in the main repository.
- Not packaged: Quickshell, awww and the Nerd Font. Build them from source or use OBS home projects.
- Leap is too old.

## Debian, Ubuntu and derivatives
- The packaged Hyprland is far older than 0.55, and Quickshell, awww and rofi 2.x are not packaged.
- You would have to build Hyprland, Quickshell, awww and rofi from source. This is possible, but expect work.
- The rest (`wl-clipboard`, `cliphist`, `jq`, `grim`, `slurp`, `kitty`, `fonts-inter`, …) comes from apt.

## Without systemd
The power menu and idle suspend call `systemctl suspend|reboot|poweroff`. Locking before sleep and on `loginctl lock-session`
listens to systemd-logind on D-Bus. On Artix, Void, Gentoo with OpenRC and similar systems these do nothing unless you provide
compatible commands (for example elogind with a `systemctl` shim). Everything else works. The installer warns about this.
The greeter needs systemd as well: its installer manages `greetd.service` with `systemctl`.

## Login greeter
The optional greeter (see [GREETER.md](GREETER.md)) installs `greetd` with pacman, dnf, apt or zypper. It detects the greeter
account name (`greeter`, `_greetd` or `greetd`). This has only been run for real on CachyOS.
