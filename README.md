<div align="center">

# Sleek Shell

**A complete, aesthetic and functional desktop environment for [Hyprland](https://hypr.land), built with [Quickshell](https://quickshell.org).**

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.3.0-7c9cff.svg)](VERSION)
[![Platform](https://img.shields.io/badge/platform-CachyOS%20%7C%20Arch%20Linux-23a7d9.svg)](docs/DISTROS.md)
[![Hyprland](https://img.shields.io/badge/Hyprland-0.55%2B-58e1a6.svg)](https://hypr.land)
[![Quickshell](https://img.shields.io/badge/Quickshell-0.3.x-ffb86c.svg)](https://quickshell.org)
[![Made with QML](https://img.shields.io/badge/made%20with-QML-41cd52.svg)](quickshell)

One command turns a minimal Arch/CachyOS install into the reference desktop:
compositor, shell, drivers, services, apps, boot animation, wallpapers, shell profile,
auto-login and auto-lock included.

</div>

---

## Table of contents

- [What you get](#what-you-get)
- [The look](#the-look)
- [Requirements](#requirements)
- [Installation](#installation)
  - [One command](#one-command)
  - [Installer options](#installer-options)
  - [What the installer does](#what-the-installer-does)
  - [Auto-login and auto-lock](#auto-login-and-auto-lock)
- [Keybinds](#keybinds)
- [Applications](#applications)
- [Theming](#theming)
- [Shell and boot](#shell-and-boot)
- [Repository layout](#repository-layout)
- [Documentation](#documentation)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [Contributing](#contributing)
- [Credits](#credits)
- [License](#license)

---

## What you get

Sleek Shell is not a theme pack. It is a full desktop session: the compositor config, the
shell process, the settings app, the lock screen, the login screen, the boot experience and
the installer that puts them all together.

| Area | What is included |
|---|---|
| **Compositor** | Hyprland with Lua configuration: monitors, workspaces, gaps, blur, rounding, shadows, animations, window rules, per-app rules and a keybind layer |
| **Bar** | Top bar on every monitor: workspaces, focused window, clock, media, network, Bluetooth, volume, microphone, battery, notifications, tray and a launcher island |
| **Panels** | Calendar, notifications, clipboard history, sound, Wi-Fi, Bluetooth, battery, power, brightness, appearance and media |
| **Lock screen** | Pixel-inspired session lock with five clock styles, wallpaper blur/shade controls, PAM authentication, a short fade-in and **one password field on the focused monitor** |
| **Overview** | Workspace overview, window switcher (`ALT+Tab`), workspace strip and drag-to-move workspaces |
| **Settings** | A real settings app: appearance, palettes, fonts, icons, cursors, wallpapers, displays, keyboard shortcuts, lock screen, bar, idle and about |
| **Launcher** | Rofi launcher, clipboard history and an offline calculator / unit converter |
| **Notifications** | Native Quickshell notification server with toasts, history and per-app controls |
| **Login screen** | Optional Sleek Shell greeter for `greetd`, matching the desktop theme |
| **Boot** | Plymouth boot animation, themed GRUB menu, `quiet splash`, and an initramfs rebuilt by the installer |
| **Apps** | Zen Browser (default), Thunar + volume manager, Resources, nwg-displays, kitty, Cava, fastfetch, eza and the usual desktop services |
| **Wallpapers** | The full free/open-source collection (200+ images) copied into `~/Pictures/Wallpapers` |
| **Shell profile** | zsh + Powerlevel10k + autosuggestions + syntax highlighting + eza aliases, with a safe `~/.zshrc.local` hook |
| **Power** | PipeWire audio, NetworkManager, Bluetooth, power profiles, brightness/media keys, idle dim → lock → screen off → suspend |
| **Installer** | Idempotent, backed up, dry-runnable, verified, and reversible with an uninstaller |

Everything above is installed and arranged by `./install.sh`. You do not have to copy config
files by hand or run a second setup script.

## The look

The reference desktop is dark, glassy and compact:

- deep navy/graphite surfaces with a single accent colour;
- rounded, blurred dropdown islands instead of a separate panel window;
- JetBrainsMono Nerd Font for the bar and terminal, Inter/Noto Sans for applications;
- Papirus Dark icons and Adwaita cursors;
- the `lone` Plymouth animation and the `stylish` GRUB theme at boot;
- a Pixel-inspired lock screen with a large clock and a single password capsule.

Every colour, radius, blur strength, gap, font and animation speed is editable live in
**Settings → Appearance**, **Windows**, **Fonts, icons & cursors** and **Motion**. The settings
app writes the compositor state, so changes survive `hyprctl reload` and a reboot.

## Requirements

- **CachyOS** (reference, fully supported) or **Arch Linux** and Arch-based distributions
  (EndeavourOS, Manjaro, Garuda, …) with `systemd`.
- A **UEFI or BIOS** install with **GRUB** for the themed boot menu. Plymouth is configured
  when it is installed; other bootloaders keep their current menu.
- An **x86_64** machine. Intel, AMD and NVIDIA GPUs are detected; the installer picks the
  right driver (including the NVIDIA open modules).
- A network connection during install (packages, AUR helper, Powerlevel10k).
- ~5 GB free disk space for packages and wallpapers.
- Other distributions: the files install into your home, but packages are listed rather than
  installed. See [docs/DISTROS.md](docs/DISTROS.md).

> The installer never runs as root. It asks for `sudo` once and lists every privileged
> command in `--dry-run` before doing anything.

## Installation

### One command

```bash
git clone https://github.com/mvjishnu/sleek-shell.git
cd sleek-shell
./install.sh
```

The installer asks for the few real choices (browser and idle timeouts), shows a plan, and then
installs the reference setup: TTY1 auto-login with the PAM lock before the desktop is usable.
To accept every default without questions:

```bash
./install.sh --yes
```

To see exactly what would happen, including every `sudo` command, without changing anything:

```bash
./install.sh --dry-run
```

To inspect the machine and the plan only:

```bash
./install.sh --check
```

After the first install, reboot so the new drivers, services and boot theme take effect:

```bash
systemctl reboot
```

### Installer options

| Option | Meaning |
|---|---|
| `--browser firefox\|chromium\|vivaldi\|brave\|zen\|chrome\|epiphany\|none` | Browser to install and make default (default: **Zen Browser**) |
| `--greeter auto\|sleek\|keep` | Login screen: `auto` installs and enables the Sleek greeter when there is none, `sleek` replaces the current one (after asking), `keep` leaves it alone (default; TTY1 auto-login starts the desktop instead) |
| `--idle short\|balanced\|long\|never` | Lock / screen off / suspend timeouts (default: **balanced**) |
| `--lock-after MIN` | Exact auto-lock timeout in minutes (`0` = never) |
| `--screen-off-after MIN` | Exact screen-off timeout |
| `--suspend-after MIN` | Exact suspend timeout |
| `--autologin yes\|no` | TTY1 auto-login (default: **yes**); the session locks before the desktop is usable. `no` keeps a normal TTY login |
| `--nvidia open\|580xx\|nouveau` | Override the detected NVIDIA driver |
| `--profile full\|shell` | Full desktop, or only the Quickshell shell (keep your Hyprland config) |
| `--replace-hypr` | Replace an existing `~/.config/hypr` (backed up first) |
| `--keep-shell` | Do not change your login shell to zsh |
| `--user-only` | No `sudo`: install into your home only |
| `--ignore-deps` | Install files even when required programs are missing |
| `--install-deps`, `--with-optional` | Other distributions: install missing packages after asking |
| `--yes`, `--dry-run`, `--check`, `--help` | Non-interactive, preview, report, usage |

### What the installer does

1. **Detects** the distribution, init system, display manager, GPU, monitors and existing config.
2. **Plans** packages from the repositories and the AUR, the GPU driver, services and every file.
3. **Installs** (Arch/CachyOS, with `sudo`):
   - Hyprland, Quickshell, portals, polkit agent, PipeWire, NetworkManager, Bluetooth, UPower,
     power-profiles-daemon;
   - kitty, awww, rofi, clipboard tools, grim/slurp, jq, libnotify, pavucontrol, brightnessctl,
     playerctl;
   - Thunar + `thunar-volman` + `gvfs`, **Resources**, **nwg-displays**, Cava, eza, fastfetch;
   - zsh + completions + autosuggestions + syntax highlighting + fzf;
   - fonts (JetBrainsMono Nerd Font, Noto, Inter), Papirus icons, Adwaita cursors;
   - the chosen browser (**Zen Browser** by default);
   - on CachyOS: Plymouth, the CachyOS Plymouth themes and the CachyOS GRUB theme;
   - the GPU driver and its suspend services.
4. **Configures** (with backups and idempotent writes):
   - TTY1 auto-login (default; `--autologin no` disables it) and the PAM-authenticated lock on startup;
   - the greeter files, ready for `--greeter sleek` or a later enable;
   - PipeWire, NetworkManager, Bluetooth, power profiles, login shell;
   - Plymouth theme, `plymouth`/`plymouth-shutdown` mkinitcpio hooks, GRUB theme, `quiet splash`,
     then `mkinitcpio -P` and `grub-mkconfig`;
   - idle dim → lock → screen off → suspend, separately on AC and battery.
5. **Installs into your home**:
   - `~/.config/quickshell` (the shell) and `~/.config/hypr` (the compositor);
   - `~/.zshrc`, `~/.zprofile`, `~/.p10k.zsh` and Powerlevel10k (only where you have none);
   - rofi, kitty and app-theme defaults (only where you have none);
   - the calculator, icon font and the full wallpaper collection;
   - docs, the greeter files and `~/.local/share/sleek-shell/uninstall.sh`.
6. **Verifies** the result and writes `~/.local/share/sleek-shell/install-report.txt`.

Replaced files are moved to `~/.local/share/sleek-shell-backups/<date>/`; the uninstaller
restores them.

### Auto-login and auto-lock

Auto-login is **on by default**, matching the reference desktop. `--autologin no` keeps a normal
TTY login; `--greeter sleek` installs and enables the graphical greeter instead. When auto-login is on:

- `getty@tty1` logs the user in automatically;
- `~/.zprofile` starts Hyprland only on VT1 and only when no Wayland session is running;
- `hypr/scripts/start-shell` asks Quickshell for a **PAM-authenticated lock before the desktop
  is usable**, so auto-login does not expose your session;
- the startup lock flag is consumed once, so reloading the shell never re-locks an unlocked session.

The greeter is a separate, optional login screen. Its files are always installed under
`~/.local/share/sleek-shell/greeter`; run `sudo ~/.local/share/sleek-shell/greeter/install.sh --enable`
(or re-run the installer with `--greeter sleek`) to use it instead of TTY1 auto-login.

Auto-lock is always configured through the idle settings: dim, lock, screen off and suspend,
with separate values on battery. The default `balanced` preset locks after 10 minutes and turns
the screen off after 15. Change it live in **Settings → Idle**, or re-run the installer with
`--idle`/`--lock-after`.

## Keybinds

`SUPER` is the main modifier. All binds are listed and editable in **Settings → Keyboard**;
changes are written to `~/.config/sleek-shell/keybinds.json` and survive reloads.

| Key | Action |
|---|---|
| `SUPER + T` | Terminal (kitty) |
| `SUPER + R` / tap `SUPER` | App launcher (rofi) |
| `SUPER + B` | Zen Browser |
| `SUPER + E` | File manager (Thunar) |
| `SUPER + Q` | Close window |
| `SUPER + M` | Exit Hyprland |
| `SUPER + L` | Lock the session |
| `SUPER + V` | Toggle floating |
| `SUPER + P` | Pseudo-tile |
| `SUPER + J` | Toggle split (dwindle) |
| `SUPER + W` / `SUPER + SHIFT + W` | Next / previous wallpaper |
| `SUPER + S` / `SUPER + SHIFT + S` | Region / full screenshot |
| `SUPER + ALT + C` | Calculator & unit converter |
| `SUPER + left/right` | Previous / next workspace on this monitor |
| `SUPER + up/down` | Focus window in that direction |
| `SUPER + 1…0` | Switch workspace |
| `SUPER + SHIFT + 1…0` | Move window to workspace |
| `SUPER + Tab` | Workspace overview |
| `ALT + Tab` / `ALT + SHIFT + Tab` | Window switcher |
| `SUPER + K` | Keybind cheatsheet |
| `SUPER + I` | Settings |
| `SUPER + SHIFT + D` | Display settings (nwg-displays) |
| `SUPER + SHIFT + A` | Appearance panel |
| `SUPER + SHIFT + Escape` | Reset the keybind submap |
| `SUPER + drag` / `SUPER + right-drag` | Move / resize window |
| Volume, mic, brightness, media keys | Work on the lock screen too |

The full table, including shell IPC commands, is in [docs/KEYBINDS.md](docs/KEYBINDS.md).

## Applications

| App | Role |
|---|---|
| **Zen Browser** | Default browser (`--browser` changes it) |
| **Thunar** | File manager, with `thunar-volman` and `gvfs` for drives, mounts and trash |
| **Resources** | System monitor (CPU, memory, GPU, disks, processes) |
| **nwg-displays** | Monitor layout editor; writes `~/.config/hypr/monitors.lua` |
| **kitty** | Default terminal |
| **rofi** | Launcher, clipboard history and calculator UI |
| **Cava** | Audio visualiser in the media panel (sleeps when idle) |
| **fastfetch** | System info in the terminal (`ff`) |
| **eza** | `ls`, `ll`, `la`, `tree` replacements |
| **Sleek Calculator** | Offline rofi calculator and unit converter |
| **Sleek Settings** | The desktop settings app |

Optional extras (installed when available): `pavucontrol`, `blueman`, `nm-connection-editor`,
ImageMagick, WebP support and the rofi plugin build toolchain.

## Theming

The design system lives in `quickshell/services/Theme.qml`. Settings writes JSON/Lua state,
never the QML source, so upgrades keep your choices.

| Setting | Where it is stored |
|---|---|
| Palette, accent, style mode, radius, opacity, shadows | `~/.config/sleek-shell/appearance.json` |
| Window borders, blur, gaps, animation speed | `~/.config/sleek-shell/hypr-look.lua` |
| Fonts, icons, cursors | `~/.config/sleek-shell/hypr-cursor.lua` + app configs |
| Wallpaper folder, transition, lock wallpaper | `~/.config/sleek-shell/settings.json` |
| Idle and auto-lock timeouts | `~/.config/sleek-shell/settings.json` |
| Keyboard shortcuts | `~/.config/sleek-shell/keybinds.json` → `hypr-binds.lua` |
| Monitor layout | `~/.config/hypr/monitors.lua` (nwg-displays) |
| Per-app theme scope | `~/.config/sleek-shell/app-themes.json` |

Sleek Shell only recolours apps whose config it installed (rofi and kitty by default).
GTK, Qt/KDE, micro and your own configs stay untouched until you enable them in
**Settings → Appearance → Apps**.

## Shell and boot

- **Reload the shell:** `quickshell ipc call reload reload`
- **Restart the shell:** `pkill -x quickshell; hyprctl dispatch 'hl.dsp.exec_cmd("quickshell")'`
- **Lock now:** `quickshell ipc call lock lock`
- **Bar geometry debug:** `quickshell ipc call debug barGeometry <screen>`
- **Boot theme:** Plymouth `lone`, GRUB `stylish`, `quiet splash`
- **Boot settings:** `/etc/plymouth/plymouthd.conf`, `/etc/default/grub`, `/etc/mkinitcpio.conf`
- **Startup log:** `~/.local/state/quickshell/startup.log`
- **Hyprland log:** `~/.local/state/hyprland/startup.log`

The installer backs up every system file it edits and regenerates the initramfs and GRUB menu
only when something actually changed.

## Repository layout

```text
sleek-shell/
├── install.sh              one-command installer (system + home)
├── uninstall.sh            restores backups and removes installed files
├── lib/                    installer library: distro, deps, GPU, Arch, privileges
├── quickshell/             the shell (Quickshell 0.3.x)
│   ├── shell.qml           composition root
│   ├── services/           Theme, Settings, Sys, Wm, Notifs, Ui, Time, Cava, StyleLibrary
│   ├── components/         reusable controls
│   ├── modules/            bar, panels, notifications, pixel lock, overview, keybinds, monitors, settings
│   ├── scripts/            helper scripts
│   └── cava.conf           audio visualiser config
├── hypr/                   Hyprland Lua configuration
│   ├── hyprland.lua        entry point
│   ├── modules/            env, monitors, workspaces, autostart, layers, misc, keybinds, decorations, layout, input, window rules
│   ├── sleekshell/         theme state loaders, keybind layer, cursor
│   └── scripts/            start-shell, wallpaper-next, control-osd, polkit-agent, enable-autologin, hypr-tools.py
├── greeter/                optional greetd login screen
├── defaults/               rofi, kitty, zsh and app-theme defaults
├── assets/                 fonts + the free/open-source wallpaper collection
├── calc/                   offline rofi calculator
├── docs/                   full documentation
└── tests/                  static, Lua, QML, distro, GPU, installer and live checks
```

## Documentation

| Document | Contents |
|---|---|
| [docs/INSTALL.md](docs/INSTALL.md) | Detailed install, options, boot, auto-login, verification |
| [docs/CONFIG.md](docs/CONFIG.md) | Every config file, what owns it and how to change it |
| [docs/KEYBINDS.md](docs/KEYBINDS.md) | Complete keybind reference |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the shell, services and compositor fit together |
| [docs/QUICKSHELL.md](docs/QUICKSHELL.md) | QML module map and development workflow |
| [docs/LOCKSCREEN.md](docs/LOCKSCREEN.md) | Lock screen, PAM, fade-in and single-screen password |
| [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md) | Package table for every distribution |
| [docs/DISTROS.md](docs/DISTROS.md) | Support level and package notes per distribution |
| [docs/GREETER.md](docs/GREETER.md) | Optional greetd login screen |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common problems and fixes |
| [docs/UNINSTALL.md](docs/UNINSTALL.md) | Removing Sleek Shell and restoring backups |
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Development, tests and style |

## Troubleshooting

| Symptom | Fix |
|---|---|
| Shell did not start | `cat ~/.local/state/quickshell/startup.log`; run `quickshell` in a terminal |
| Hyprland config error | `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua` |
| No bar | `quickshell ipc call health ready` should print `ok`; reload the shell |
| No boot animation | Check `Theme=` in `/etc/plymouth/plymouthd.conf`, then `sudo mkinitcpio -P` |
| GRUB menu unthemed | Check `GRUB_THEME` in `/etc/default/grub`, then `sudo grub-mkconfig -o /boot/grub/grub.cfg` |
| No wallpapers | Re-run `./install.sh`; it copies the collection into `~/Pictures/Wallpapers` |
| zsh prompt is plain | `git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.powerlevel10k` |
| No auto-login | `sudo ~/.config/hypr/scripts/enable-autologin`, then reboot |
| No auto-lock | Set the timeouts in **Settings → Idle** or `./install.sh --idle balanced` |
| NVIDIA issues | Re-run `./install.sh --nvidia open` (or `580xx`/`nouveau`) |

More in [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Uninstall

```bash
~/.local/share/sleek-shell/uninstall.sh
```

It removes the files the installer placed, restores the backups, and leaves your personal
files and wallpapers alone. See [docs/UNINSTALL.md](docs/UNINSTALL.md).

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first; it covers
the test suites (`tests/run.sh`), the QML/Lua conventions and the review checklist.

## Credits

- [Hyprland](https://hypr.land) — the compositor.
- [Quickshell](https://quickshell.org) — the shell framework.
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k) — the zsh prompt.
- [CachyOS](https://cachyos.org) — the reference distribution and boot themes.
- The authors of the free/open-source wallpapers in `assets/wallpapers`.
- Every upstream project whose packages make this desktop possible.

Sleek Shell is an independent project. It is not affiliated with Hyprland, Quickshell or CachyOS.

## License

Sleek Shell is free software, licensed under the **GNU General Public License v3.0**.
See [LICENSE](LICENSE) for the full text.

```text
Copyright (C) 2026 mvjishnu

This program is free software: you can redistribute it and/or modify it under the terms of
the GNU General Public License as published by the Free Software Foundation, either version 3
of the License, or (at your option) any later version.
```
