# Architecture

Sleek Shell has three layers:
1. Hyprland is configured in Lua.
2. A Quickshell desktop shell sits on top of it.
3. Small scripts connect the two and push the theme to other apps.

The shell owns all state. Hyprland reads only small files that the shell generates.

```
                ┌──────────────────────── Quickshell (~/.config/quickshell) ───────────────────────┐
  you ──keys──▶ │ bar · panels · notifications · overview · switcher · lock · settings (SUPER+I)   │
                │ services/: Theme · Settings · Sys · Notifs · Wm · Ui · Time · StyleLibrary · Cava │
                └──────┬──────────────────────────┬─────────────────────────────┬──────────────────┘
          global shortcuts / IPC        writes ~/.config/sleek-shell/       runs scripts/
                       │                          │                             │
                ┌──────▼──────────────┐   ┌───────▼─────────────────┐   ┌───────▼──────────────────────┐
                │ Hyprland            │◀──│ hypr-look.lua           │   │ apply-theme.sh → kitty, rofi,│
                │ hyprland.lua        │   │ hypr-binds.lua          │   │   GTK, Qt/KDE, micro         │
                │ modules/ (yours to  │   │ hypr-cursor.lua         │   │ desktop-prefs.py → fonts,    │
                │   read and copy)    │   │ settings / appearance   │   │   icons, cursors             │
                │ sleekshell/ (glue)  │   │   .json                 │   │ asset-store.py → downloads   │
                └─────────────────────┘   └─────────────────────────┘   └──────────────────────────────┘
```

## Hyprland (`hypr/`)

`hyprland.lua` loads the files below in this order. Anything optional is wrapped in `pcall`, so one broken file
cannot take the config down.

| File | Role |
|---|---|
| `modules/env.lua` | Toolkit and Wayland variables, NVIDIA offload hints, cursor (via `sleekshell/cursor.lua`) |
| `modules/monitors.lua` | Loads the nwg-displays layout (`monitors.lua`) and `monitors_custom.lua`; safe fallback when neither exists |
| `modules/decorations.lua`, `layout.lua`, `misc.lua`, `input.lua`, `layers.lua`, `windowrules.lua` | Standard Hyprland settings. `decorations.lua` applies `sleekshell/look.lua` (your Settings → Windows values) |
| `sleekshell/bindlayer.lua` | Wraps `hl.bind` so that Settings can disable, move or relabel any bind loaded after it (`hypr-binds.lua`) |
| `modules/keybinds.lua`, `modules/shell_keys.lua` | Default shortcuts ([KEYBINDS.md](KEYBINDS.md)) |
| `custom_binds.lua` | Your binds from Settings → Keyboard (not shipped) |
| `modules/autostart.lua` | `start-shell` (Quickshell), `polkit-agent`, the cliphist watchers, `awww-daemon` |
| `modules/workspaces.lua`, `workspace_state.lua` | Independent workspaces per monitor, stored in `~/.local/state/hyprland/workspaces.txt` |
| `user.lua` | Your additions, loaded last (not shipped) |

The shell changes Hyprland live with `hyprctl eval "require('sleekshell.look').apply()"` and similar calls. It never uses
`hyprctl keyword`, so the values survive `hyprctl reload`. `scripts/hypr-tools.py` lists binds and monitors as JSON for
the Settings app; `scripts/start-shell` starts the shell and requests the PAM startup lock; `scripts/wallpaper-next`
cycles wallpapers; `scripts/control-osd` drives volume and brightness keys; `scripts/enable-autologin` writes the TTY1
auto-login unit.

## Boot (`/etc`)

The reference boot is configured by the installer, not by a file in this repository:

| File | Value |
|---|---|
| `/etc/plymouth/plymouthd.conf` | `Theme=lone` (CachyOS animation) |
| `/etc/mkinitcpio.conf` | `HOOKS=(… plymouth filesystems plymouth-shutdown)` |
| `/etc/default/grub` | `GRUB_THEME="/usr/share/grub/themes/stylish/theme.txt"`, `quiet splash`, `GRUB_GFXMODE=1920x1080,auto` |

`arch_boot_apply` in `lib/arch.sh` edits these idempotently, backs them up under
`~/.local/share/sleek-shell-backups/<date>/system/`, and runs `mkinitcpio -P` and `grub-mkconfig` only when
something changed. On systems without Plymouth/GRUB the current boot is left untouched.

## Quickshell (`quickshell/`)

`shell.qml` only composes modules. The logic lives in singleton services, and every visual value comes from `Theme`.
Directory layout, IPC targets and coding rules are in [QUICKSHELL.md](QUICKSHELL.md). The lock screen is described in
[LOCKSCREEN.md](LOCKSCREEN.md).

Communication with Hyprland goes three ways:
- **Shell → Hyprland**: `hyprctl eval` / `hyprctl dispatch`, plus Quickshell's Hyprland module for events (windows,
  workspaces, monitors).
- **Hyprland → shell**: global shortcuts (`hl.dsp.global("quickshell:…")`) and `quickshell ipc call …` from binds.
- **Theme to other apps**: `scripts/apply-theme.sh` reads `theme-export.json` and rewrites marked blocks only
  ([CONFIG.md](CONFIG.md#app-theming)).

## Other parts

| Path | Role |
|---|---|
| `calc/` | Calculator and unit converter: a rofi plugin (`rofi-sleek-calc.c`, built if a compiler is present) with a Python script-mode fallback. See `calc/README.md` |
| `defaults/` | kitty, rofi and app-theme defaults, installed only if absent |
| `assets/fonts/` | Material Symbols Rounded (Apache-2.0), installed per user |
| `assets/wallpapers/` | The full free/open-source wallpaper collection (200+ images), copied to `~/Pictures/Wallpapers` without overwriting yours ([LICENSE.md](../assets/wallpapers/LICENSE.md)) |
| `greeter/` | Optional greetd login screen: its own Quickshell UI and a minimal Hyprland config, installed with sudo ([GREETER.md](GREETER.md)) |
| `lib/` | Installer libraries: `common.sh` (copy, backup, manifest), `distro.sh` (read-only detection), `deps.sh` (dependency table) |
| `install.sh`, `uninstall.sh` | Per-user install and removal ([INSTALL.md](INSTALL.md), [UNINSTALL.md](UNINSTALL.md)) |
| `tests/` | Test suites, all run in `/tmp` ([CONTRIBUTING.md](../CONTRIBUTING.md#development)) |

## State on disk

| Where | What |
|---|---|
| `~/.config/sleek-shell/` | Every user setting (Settings app). The only thing to back up |
| `~/.local/share/sleek-shell/` | Install manifest, uninstaller, docs, greeter source, reference Hyprland config, `assets.json` (downloads) |
| `~/.local/share/sleek-shell-backups/` | Files the installer replaced |
| `~/.local/state/hyprland/workspaces.txt` | Per-monitor workspace allocation |
| `~/.local/state/awww-rice/` | Last wallpaper |
| `~/.local/state/quickshell/startup.log` | Shell startup log |
| `~/.local/state/hyprland/startup.log` | Hyprland startup log (auto-login) |
| `~/Pictures/Wallpapers/` | Wallpapers (the shipped collection plus yours) |
| `~/.zshrc`, `~/.zprofile`, `~/.p10k.zsh`, `~/.powerlevel10k/` | Shell profile and prompt |
| `/etc/systemd/system/getty@tty1.service.d/sleek-shell-autologin.conf` | TTY1 auto-login (opt-in) |
| `/etc/greetd/sleek-shell/` | Greeter only: a copy of your look, made at greeter install or `--sync` |
