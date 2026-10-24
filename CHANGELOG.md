# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-10-24

### Added
- **One installer for the whole desktop on Arch.** `./install.sh` now turns a fresh minimal Arch (or Arch-based)
  system into a working desktop: a full upgrade plus every package in one pacman transaction, AUR packages only
  when needed (yay-bin bootstrapped as the user), GPU drivers, PipeWire/NetworkManager/Bluetooth/power services,
  the greetd greeter, zsh, home folders, then a verification step and a report. See `docs/INSTALL.md`.
  - Only three questions: browser, replacing an existing display manager (default no), idle timeouts.
    `--browser`, `--greeter`, `--idle`, `--lock-after`, `--screen-off-after`, `--suspend-after` answer them.
  - GPU detection from sysfs: NVIDIA open modules for Turing and newer, `nvidia-580xx-dkms` for Pascal/Maxwell,
    nouveau for older cards, kernel-matched packages, PRIME offload on hybrid laptops, modprobe options with an
    initramfs rebuild, NVIDIA suspend services. `--nvidia` overrides it.
  - `--dry-run` prints every sudo command; `--check` is read-only; `--user-only` keeps the old per-user install.
  - Exit status 4 when a post-install check fails. Report: `~/.local/share/sleek-shell/install-report.txt`;
    every system change is appended to `system-changes.log`, which the uninstaller prints.
- Idle: the screen dims before it locks or turns off (Settings › Lock screen, 30 seconds by default, any input
  brings it back), and laptops can use separate, shorter timeouts on battery. The installer's idle presets set
  both on laptops. `quickshell ipc call idle status` shows the timeouts in effect.
- A default `~/.zshrc` (history, completion, `~/.local/bin` on PATH, autosuggestions and syntax highlighting).
- Built-in laptop panels get scale 1.25 when it gives a whole-pixel desktop.
- `XDG_MENU_PREFIX=arch-` when `archlinux-xdg-menu` is installed, so Dolphin's "Open with" works outside Plasma.
- `tests/system.sh`, `tests/gpu.sh`, `tests/lua.sh`, `tests/qml` (qmltestrunner) and Python unit tests for the shortcut editor.

### Fixed
- Connecting a new monitor crashed `workspaces.lua`: a line starting with `(` was parsed as a call on the
  previous expression.
- The shortcut editor rolled back every change when Hyprland already reported a config error, and read
  `hyprctl configerrors` without `-j`. It now compares against the errors present before the change.
- A first terminal ran zsh's new-user wizard because no `~/.zshrc` was installed.
- kitty and rofi theming was skipped when a previous install had stopped half way; files that are already
  Sleek Shell's are now adopted.
- A `~/.config/hypr` that Hyprland generated on its first start blocked the Sleek Shell config; it is now replaced
  (backed up).
- `~/.local/bin` was not on PATH in the session, and NVIDIA variables were set globally on hybrid laptops.

### Added (earlier, unreleased)
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
