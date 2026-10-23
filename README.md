# Sleek Shell

A complete desktop shell for [Hyprland](https://hypr.land) built with [Quickshell](https://quickshell.org):
bar, dropdown panels, notifications, lock screen, workspace overview, app switcher, a settings app
that themes your whole desktop, an offline calculator for rofi, and an optional greetd login screen.

![Desktop](screenshots/desktop.webp)

| | |
|---|---|
| ![Calendar](screenshots/calendar.webp) | ![Appearance panel](screenshots/appearance-panel.webp) |
| ![Sound](screenshots/sound.webp) | ![Notifications](screenshots/notifications.webp) |
| ![Settings: appearance](screenshots/settings-appearance.webp) | ![Settings: fonts, icons & cursors](screenshots/settings-fonts.webp) |
| ![Settings: launcher & calculator](screenshots/settings-launcher.webp) | ![Power menu](screenshots/power.webp) |

## Status

Version 0.1.0, the first public release.

| Distribution | Status |
|---|---|
| Arch, CachyOS and derivatives | **Tested**: developed and used daily on CachyOS |
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
- **Login greeter** (optional, separate, needs root): greetd, Hyprland, and Quickshell, in the same look.

## Install

On a clean system:

```sh
git clone https://github.com/mvjishnu/sleek-shell.git && cd sleek-shell
./install.sh --check                  # what is missing (installs nothing)
./install.sh --check --install-deps   # install the missing packages, after showing the command and asking
./install.sh --dry-run                # exactly which files would be copied and backed up
./install.sh                          # install for your user
```

Then log out and choose the Hyprland session in your display manager, or run `start-hyprland` from a TTY.

- Packages are installed only with `--install-deps`, and only after you confirm the exact command.
  - Only your distribution's own repositories are used; third-party repositories are named, never added.
  - `--with-optional` adds the optional packages.
  - It never installs or replaces a display manager.
- The rest of the installer is per-user: it never uses `sudo`, never enables services and never touches `/etc`.
- It backs up everything it replaces and records every file in a manifest, so
  `~/.local/share/sleek-shell/uninstall.sh` can undo it.
- If you already have a Hyprland config, it is **kept** unless you pass `--replace-hypr`.

Every package, per distribution: [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md). Full guide: [docs/INSTALL.md](docs/INSTALL.md).

## Documentation

| | |
|---|---|
| [INSTALL](docs/INSTALL.md) | dependencies, profiles, what goes where, upgrades |
| [DEPENDENCIES](docs/DEPENDENCIES.md) | every package per distribution, and what the installer does with it |
| [UNINSTALL](docs/UNINSTALL.md) | removing Sleek Shell and restoring your old files |
| [CONFIG](docs/CONFIG.md) | settings files, `user.lua`, environment variables, using your own Hyprland config |
| [KEYBINDS](docs/KEYBINDS.md) | every default shortcut |
| [GREETER](docs/GREETER.md) | the optional greetd login screen |
| [DISTROS](docs/DISTROS.md) | per-distribution notes and package names |
| [TROUBLESHOOTING](docs/TROUBLESHOOTING.md) | common problems and logs |
| [ARCHITECTURE](docs/ARCHITECTURE.md) | how the pieces fit together |
| [QUICKSHELL](docs/QUICKSHELL.md), [LOCKSCREEN](docs/LOCKSCREEN.md) | shell internals |

## License

MIT, see [LICENSE](LICENSE). The bundled Material Symbols font is Apache-2.0
([assets/fonts/LICENSE-MaterialSymbols.txt](assets/fonts/LICENSE-MaterialSymbols.txt)). The bundled wallpaper is
MIT ([assets/wallpapers/LICENSE.md](assets/wallpapers/LICENSE.md)).
