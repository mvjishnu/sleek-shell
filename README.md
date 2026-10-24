# Sleek Shell

A complete desktop shell for [Hyprland](https://hypr.land) built with [Quickshell](https://quickshell.org):
bar, dropdown panels, notifications, lock screen, workspace overview, app switcher, a settings app
that themes your whole desktop, an offline calculator for rofi, and a matching greetd login screen.

![Desktop](screenshots/desktop.webp)

| | |
|---|---|
| ![Calendar](screenshots/calendar.webp) | ![Appearance panel](screenshots/appearance-panel.webp) |
| ![Sound](screenshots/sound.webp) | ![Notifications](screenshots/notifications.webp) |
| ![Settings: appearance](screenshots/settings-appearance.webp) | ![Settings: fonts, icons & cursors](screenshots/settings-fonts.webp) |
| ![Settings: launcher & calculator](screenshots/settings-launcher.webp) | ![Power menu](screenshots/power.webp) |

## Status

Version 0.2.0: one installer for the whole desktop on Arch. See the [changelog](CHANGELOG.md).

| Distribution | Status |
|---|---|
| Arch, CachyOS and derivatives | **Tested**: developed and used daily on CachyOS. The full system install is tested end to end in a sandbox with stubbed `sudo`/`pacman`/`systemctl` |
| Fedora 44, openSUSE Tumbleweed | **Simulated**: package names and installer flow tested with fixtures and stubbed package managers; never installed for real |
| Debian 13, Ubuntu 26.04 | **Simulated**, and not usable from the official repositories alone (rofi or Hyprland too old) |

See [docs/DISTROS.md](docs/DISTROS.md).

| Needs | Version |
|---|---|
| Hyprland, with the Lua config | 0.55 or newer (tested on 0.56.2) |
| Quickshell | 0.2 or newer (tested on 0.3.2) |
| rofi, with Wayland support | 2.0 or newer |
| systemd | for the power menu and the greeter |

## Features

- **Bar** on every monitor: workspaces per monitor, clock, notifications, clipboard, sound, Wi-Fi,
  Bluetooth, battery, and power. You can reorder and hide widgets. A centre island shows the volume and brightness OSD and what is playing.
- **Panels**: notifications (with do-not-disturb), clipboard history (text and images), calendar, sound
  (choose the output device), Wi-Fi, Bluetooth, battery and brightness with power profiles, and a power menu.
- **Lock screen** (`SUPER+L`): blurred wallpaper with a glass card. It authenticates through PAM.
- **Workspace overview** (`SUPER+Tab`), **app switcher** (`ALT+Tab`), and **minimise** (`SUPER+H`).
- **Settings app** (`SUPER+I`) with these pages:
  - **Appearance**: 12 palettes, accent, glass/solid, blur, borders, light/dark.
  - **Fonts, icons & cursors**: can download them.
  - **Motion**, **Bar**, **Windows**, **Wallpaper** (awww), **Notifications**, **Lock screen**, **Launcher**.
  - **Keyboard**: rebind or disable any shortcut without editing a file.
  - **Displays**: arrange monitors, with a 15-second revert.
- **App theming**: the shell palette is applied to kitty, rofi, GTK 3/4, Qt/KDE, and micro. You can turn this off
  per app in Settings.
- **Calculator & unit converter** (`SUPER+ALT+C`): runs inside rofi, offline, and never calls `eval`.
- **Login greeter**: greetd, Hyprland, and Quickshell, in the same look. Installed by `./install.sh` on Arch.

## Install

On a fresh, minimal Arch Linux (or Arch-based) system, logged in as your own user with `sudo` rights:

```sh
sudo pacman -S --needed git
git clone https://github.com/mvjishnu/sleek-shell.git && cd sleek-shell
./install.sh
```

The installer shows what it found, asks up to three questions, shows the whole plan, and asks once more
before it changes anything:

1. **Web browser**: Firefox (default), Chromium, Vivaldi, Brave, Zen, Google Chrome, GNOME Web, or none.
2. **Login screen**: asked only if another display manager (SDDM, GDM, LightDM, ...) is enabled. The
   default is to keep it. With no display manager, the Sleek Shell greeter is installed.
3. **When you are away**: lock / screen off / suspend timeouts. Balanced is the default (10 / 15 min, and
   suspend after 30 min on laptops, with shorter timeouts on battery). The screen dims 30 s before it locks.

Then it does the rest itself, with `sudo`:
- installs every package the desktop uses (full system upgrade first; the AUR only for what needs it);
- installs the right GPU driver (Mesa; NVIDIA open or legacy driver; hybrid laptops get PRIME offload);
- enables PipeWire, NetworkManager, Bluetooth and power profiles, and sets up the login screen;
- makes zsh your login shell (only if it is still bash) and installs the desktop into your home;
- checks the result, writes a report, and tells you to reboot.

Run it again at any time: finished steps are skipped and nothing is installed twice.

```sh
./install.sh --dry-run    # the whole plan, including every sudo command; changes nothing
./install.sh --check      # what is installed and missing (read-only)
./install.sh --yes        # take every default, no questions
./install.sh --help       # every option
```

- Everything the installer replaces in your home is backed up, and `~/.local/share/sleek-shell/uninstall.sh` puts it back.
- Every system change is listed in `~/.local/share/sleek-shell/install-report.txt`.
- If you already have your own Hyprland config, it is **kept** unless you pass `--replace-hypr`.
- On other distributions the installer only installs into your home and lists the packages you need; see
  [docs/DISTROS.md](docs/DISTROS.md).

Full guide: [docs/INSTALL.md](docs/INSTALL.md). Every package: [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md).

## Documentation

| | |
|---|---|
| [INSTALL](docs/INSTALL.md) | the install flow, choices, options, what goes where, upgrades |
| [DEPENDENCIES](docs/DEPENDENCIES.md) | every package per distribution, and what the installer does with it |
| [UNINSTALL](docs/UNINSTALL.md) | removing Sleek Shell and restoring your old files |
| [CONFIG](docs/CONFIG.md) | settings files, `user.lua`, environment variables, using your own Hyprland config |
| [KEYBINDS](docs/KEYBINDS.md) | every default shortcut |
| [GREETER](docs/GREETER.md) | the greetd login screen |
| [DISTROS](docs/DISTROS.md) | per-distribution notes and package names |
| [TROUBLESHOOTING](docs/TROUBLESHOOTING.md) | common problems and logs |
| [ARCHITECTURE](docs/ARCHITECTURE.md) | how the pieces fit together |
| [QUICKSHELL](docs/QUICKSHELL.md), [LOCKSCREEN](docs/LOCKSCREEN.md) | shell internals |

## License

MIT, see [LICENSE](LICENSE). The bundled Material Symbols font is Apache-2.0
([assets/fonts/LICENSE-MaterialSymbols.txt](assets/fonts/LICENSE-MaterialSymbols.txt)). The bundled wallpaper is
MIT ([assets/wallpapers/LICENSE.md](assets/wallpapers/LICENSE.md)).
