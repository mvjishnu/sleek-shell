# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Dynamic, hotplug-safe monitor manager** (`hypr/modules/monitors.lua`): modes are checked against what each
  monitor reports, settings follow the physical monitor, active monitors are packed left to right, and
  `SUPER+ALT+Left/Right/R/P/M` move, rotate, reset and cycle display modes. State is kept in
  `~/.local/state/hypr/monitor-layout.lua`.
- **Fonts, icons & cursors page rework**: search, installed/available store split, confirmed `pkexec pacman`
  installs of repository icon/cursor themes, and a one-click removal of Tamil-only font families.
- Rofi follows the chosen icon theme and gets a themed border/radius; the cursor is also written to `~/.icons`
  and `~/.Xresources` for XWayland apps.
- `udiskie` automount at login (optional; skipped when not installed).
- zsh: `crun` (build and run a C/C++ file) and `code` → `codium` when only VSCodium is installed.
- README screenshots of the desktop, panels, launcher, overview, settings and power menu.

### Changed
- The Arch package set no longer installs `ttf-indic-otf` (Tamil/Indic fonts).
- Refreshed Powerlevel10k defaults (no frame).

### Fixed
- Settings → Keyboard showed the monitor shortcuts as raw Lua source; they now have proper labels and the
  action reads "Built-in Lua action".
- `remove-fonts.sh` (run as root through pkexec) now only accepts font files under the system font
  directories and a backup directory under `/var/backups/sleek-shell/`.
- Bar side edges no longer sit 0.5 px further in than the top and bottom.

## [0.3.0] - 2026-11-13

### Added
- **Full desktop sync.** The repository now ships the current live configuration: the Pixel-inspired lock
  screen, Cava audio visualiser, glass finish controls, the rotating orbit chooser, the `home`/`pixel` modules
  and the current Hyprland Lua layout (`env.lua`, `misc.lua`, `windowrules.lua`, `layers.lua`, `monitors.lua`).
- **Boot experience in the installer.** Plymouth theme (`lone`), `plymouth`/`plymouth-shutdown` mkinitcpio hooks,
  the `stylish` GRUB theme, `quiet splash`, `GRUB_GFXMODE`, then `mkinitcpio -P` and `grub-mkconfig`. System files
  are backed up and only rewritten when they change. CachyOS themes are installed automatically; other systems
  keep their boot menu unless Plymouth is already present.
- **The full wallpaper collection** (203 free/open-source images) in `assets/wallpapers`, fitted to 2560x1440
  and stripped of metadata for a sane clone size; the installer copies them to `~/Pictures/Wallpapers` and never
  overwrites existing files.
- **The reference zsh profile:** `~/.zshrc`, `~/.zprofile`, `~/.p10k.zsh` and Powerlevel10k, with eza aliases,
  history settings, autosuggestions, syntax highlighting, Rust helpers and a `~/.zshrc.local` hook.
- **Thunar as the reference file manager**, with `thunar-volman` and `gvfs`; the installer claims `inode/directory`
  only when no handler is configured.
- **Cava** is installed with the shell and sleeps when idle.
- **Auto-login and auto-lock work out of the box:** TTY1 login is enabled by default (`--autologin no` opts out),
  Quickshell locks the session with PAM before the desktop is usable, and idle dim → lock → screen off → suspend
  is configured with separate battery timeouts. The greeter files ship too and are opt-in (`--greeter sleek`).
- New HyDE-style README and refreshed documentation for every module, file and package.

### Changed
- Hyprland scripts are extensionless (`start-shell`, `wallpaper-next`, `control-osd`, `polkit-agent`,
  `enable-autologin`); `hypr-tools.py` stays for the settings app.
- The lock screen fades in over 220 ms (skipped when animations are off), refreshes the clock at lock time and
  only runs its timer while locked.
- The password capsule is shown on **one monitor only** — the monitor focused at lock time — and moves to another
  screen with a 120 ms fade if you start typing there.
- The installer plan, report and verification now include the boot theme, wallpapers, zsh profile and apps.
- Screenshots are no longer published; the repository ships wallpapers instead.

### Fixed
- Hard-coded `/home/<user>` paths in the Hyprland modules, startup script and monitor loader are now
  `$HOME`/`XDG_CONFIG_HOME` based.
- `enable-autologin` generates the systemd override for the current user instead of depending on a machine-specific
  file.
- `polkit-agent` references in the dependency table and tests follow the extensionless script name.
- The Wi-Fi/Bluetooth orbit chooser rotates continuously again (33 ms timer, about 100 s per revolution) and
  pauses while you drag a node or turn animations off.

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
- A bundled wallpaper (`assets/wallpapers/astronaut-planet.jpg`, GPL-3.0), installed only if absent.
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
