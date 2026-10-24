# Distribution support

| Family | Detected from `ID`/`ID_LIKE` | Status |
|---|---|---|
| Arch | arch, cachyos, endeavouros, manjaro, garuda, artix, … | **Tested**: developed and used daily on CachyOS |
| Fedora | fedora, nobara, ultramarine, bazzite, rhel, … | Simulated: Fedora 44 plus a COPR looks complete; never installed |
| openSUSE | opensuse-tumbleweed, opensuse-leap, sles | Simulated: Tumbleweed plus an OBS project; Leap is too old |
| Debian/Ubuntu | debian, ubuntu, linuxmint, pop, … | Simulated: needs backports or PPAs, and rofi is too old on Debian 13 |
| Anything else | NixOS, Gentoo, Void, Alpine, … | Unsupported: may work if you provide the dependencies |

**Tested** means a real install and daily use. **Simulated** means:
- the installer detects the distribution (os-release fixtures in `tests/fixtures/os-release/`, `tests/distro.sh`);
- the installer builds the right package-manager command (stubbed `dnf`/`apt`/`zypper`, `tests/deps.sh`);
- the package names and versions below were read from each distribution's package index, not installed.

**Nobody has installed Sleek Shell on these distributions yet.** Reports and fixes are welcome; see
[CONTRIBUTING.md](../CONTRIBUTING.md). The full per-package table is in [DEPENDENCIES.md](DEPENDENCIES.md).

`./install.sh --check` works everywhere: it shows what is missing and the command to install it.
`--install-deps` runs that command after you confirm. It only uses your distribution's own repositories:
packages that need a COPR, PPA, OBS project or backports are listed with the repository name, and you add it yourself.

## The hard requirements

On every distribution, these are the hard part:
- **Hyprland 0.55 or newer.** The config uses Hyprland's Lua API (`hl.*`), and older versions cannot read it.
- **Quickshell 0.2 or newer** (tested with 0.3.2). The greeter needs Quickshell 0.3+ built with the Greetd service.
- **awww**, the wallpaper daemon (the successor of swww).
- **rofi 2.0 or newer**, for native Wayland support.
- **JetBrainsMono Nerd Font**, packaged only on Arch. Elsewhere, download it from
  [nerdfonts.com](https://www.nerdfonts.com/font-downloads), unpack it into `~/.local/share/fonts`
  (or `/usr/local/share/fonts` for the greeter), and run `fc-cache -f`.

## Arch and derivatives
Everything is in the official repositories (`extra`); the AUR is used only for the NVIDIA 580xx driver and
browsers your repositories do not have. `./install.sh` installs, configures and verifies the whole desktop
(packages, GPU driver, services, login screen): see [INSTALL.md](INSTALL.md). `./install.sh --check` lists the
packages it would install. With `--user-only` only your home is changed; then install at least:
```sh
sudo pacman -S --needed hyprland quickshell python awww wl-clipboard cliphist rofi fontconfig xdg-utils \
    ttf-jetbrains-mono-nerd kitty dolphin xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent \
    wireplumber upower networkmanager libnotify glib2 jq grim slurp inter-font noto-fonts papirus-icon-theme \
    adwaita-cursors
```

Inside `arch-chroot` (before the first boot), systemd is not running: the installer refuses the system part and
asks you to run it again after booting.

## Fedora (simulated)
- Quickshell 0.2 and rofi 2.0 are in the Fedora 44 repositories.
- Hyprland and xdg-desktop-portal-hyprland: COPR `sdegler/hyprland` (`sudo dnf copr enable sdegler/hyprland`). Check
  that it ships 0.55 or newer.
- Not packaged: awww, nwg-displays and the Nerd Font. Build awww from source.
- Polkit agent: `polkit-kde`.

## openSUSE Tumbleweed (simulated)
- Hyprland (0.56) and awww are in the main repository.
- Quickshell: OBS project `home:AvengeMedia:danklinux`.
- Not packaged: the Nerd Font.
- Leap is too old.

## Debian, Ubuntu and derivatives (simulated)
- **Debian 13:**
  - Hyprland 0.55, Quickshell 0.3, xdg-desktop-portal-hyprland and hyprpolkitagent come from `trixie-backports`.
  - The packaged rofi is 1.7.5, which is X11-only: build rofi 2.x yourself.
  - awww is not packaged: build it from source.
- **Ubuntu 26.04:**
  - rofi 2.0 is packaged.
  - The packaged Hyprland is 0.53, which is too old for the Lua config. A PPA (`cppiber/hyprland`) is the alternative.
  - Quickshell comes from PPA `avengemedia/danklinux`, and awww from PPA `razvanalex/hyprland-ppa`.
- The rest (`wl-clipboard`, `cliphist`, `jq`, `grim`, `slurp`, `kitty`, `fonts-inter`, …) comes from apt.

## Dolphin outside Plasma
Outside a Plasma session, Dolphin's "Open with" list is empty unless a KDE application menu is installed. On Arch,
`./install.sh` installs `archlinux-xdg-menu`, and the Hyprland config then sets `XDG_MENU_PREFIX=arch-` (only when
`/etc/xdg/menus/arch-applications.menu` exists and you have not set it yourself). Run `kbuildsycoca6` once if the
list stays empty. Elsewhere, set `hl.env("XDG_MENU_PREFIX", "...")` in `~/.config/hypr/user.lua` to match your
distribution's menu file. `SUPER+E` opens your default file manager (`xdg-mime query default inode/directory`).

## Without systemd
The power menu and idle suspend call `systemctl suspend|reboot|poweroff`. Locking before sleep and on `loginctl lock-session`
listens to systemd-logind on D-Bus. On Artix, Void, Gentoo with OpenRC and similar systems these do nothing unless you provide
compatible commands (for example elogind with a `systemctl` shim). Everything else works. The installer warns about this.
The greeter needs systemd as well: its installer manages `greetd.service` with `systemctl`.

## Login greeter
On Arch, `./install.sh` sets up the greeter. Elsewhere, the greeter installer (see [GREETER.md](GREETER.md)) installs `greetd`, Inter, and (on Arch) the Nerd Font system-wide, with
pacman, dnf, apt or zypper. Your package manager asks before it installs anything. The greeter detects the account name
(`greeter`, `_greetd` or `greetd`). This has only been run for real on CachyOS.
