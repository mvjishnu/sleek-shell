# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `install.sh --install-deps` installs missing required and recommended packages from the distribution's own
  repositories. `--with-optional` adds the optional ones.
  - It shows the exact command and runs it only after you type `y`. `--yes` does not answer this question,
    and with no terminal the answer is no.
  - Your package manager keeps its own prompt (no `--noconfirm` / `-y`).
  - It refuses display-manager packages.
  - Packages from third-party repositories are named, never installed.
- Dependency checks for things the default config uses but v0.1.0 did not list:
  - XDG portals (hyprland, gtk) and a polkit agent;
  - a file manager (Dolphin suggested);
  - upower, gdbus, pipewire-pulse;
  - Noto Sans, Papirus-Dark and the Adwaita cursor;
  - blueman, nm-connection-editor, qt6-imageformats, bsdtar, pciutils.
- `hypr/scripts/polkit-agent.sh`, started at login: runs the first installed polkit agent unless one is already running.
- Hints for installed services that are not running (NetworkManager, bluetooth, power-profiles-daemon,
  PipeWire, WirePlumber) and for other notification daemons. Nothing is started or enabled.
- `docs/DEPENDENCIES.md`: every package per distribution, and what the installer does with it.

### Changed
- Fedora: Hyprland comes from COPR `sdegler/hyprland`. Debian/Ubuntu and openSUSE now name the backports,
  PPAs or OBS projects that ship Hyprland, Quickshell and awww.
- `imagemagick` accepts either `magick` or `convert`.
- The greeter installer no longer passes `--noconfirm` / `-y` to the package manager, installs Inter on openSUSE,
  and installs (on Arch) or warns about a missing system-wide JetBrainsMono Nerd Font.
- The README and docs separate tested distributions (Arch/CachyOS) from simulated ones.

## [0.1.0] - 2026-10-23

First public release.

### Added
- Quickshell desktop shell, including:
  - a bar on every monitor;
  - panels;
  - notifications;
  - the lock screen;
  - the workspace overview, app switcher and minimise;
  - the settings app.
- Hyprland Lua configuration, including:
  - a keybind layer that the Settings app can rebind;
  - per-monitor workspaces;
  - theme and cursor hooks.
- App theming for kitty, rofi, GTK 3/4, Qt/KDE and micro.
- rofi calculator and unit converter, with an optional C plugin and a script fallback.
- A bundled wallpaper (`assets/wallpapers/astronaut-planet.png`, MIT), installed only if absent.
- Optional greetd login greeter with separate install and rollback scripts.
- Per-user installer (`install.sh`):
  - `full` and `shell` profiles;
  - `--check` and `--dry-run`;
  - a file manifest;
  - timestamped backups.
- Uninstaller that removes only unchanged installed files and restores backups.
- Distro, init-system and display-manager detection, with package hints for Arch, Fedora, Debian/Ubuntu and openSUSE.
- Test suite (`tests/run.sh`) with these suites: static, hygiene, distro fixtures, calculator, app themes, installer, greeter fixtures and live session.
- Environment overrides: `SLEEK_TERMINAL`, `SLEEK_FILE_MANAGER`, `SLEEK_BROWSER`, `SLEEK_NO_NVIDIA_ENV`, `WALLPAPER_DIR`.
- `~/.config/hypr/user.lua` for personal Hyprland additions. The installer never touches it.
