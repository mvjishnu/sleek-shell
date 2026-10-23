# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
