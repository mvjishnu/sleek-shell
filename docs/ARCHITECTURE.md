# Architecture

Sleek Shell has three layers:
1. Hyprland is configured in Lua.
2. A Quickshell desktop shell sits on top of it.
3. Small scripts connect the two and push the theme to other apps.

The shell owns all state. Hyprland reads only small files that the shell generates.

```
                ┌──────────────────────── Quickshell (~/.config/quickshell) ───────────────────────┐
  you ──keys──▶ │ bar · panels · notifications · overview · switcher · lock · settings (SUPER+I)   │
                │ services/: Theme · Settings · Sys · Notifs · Wm · Ui · Time · StyleLibrary       │
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
| `modules/environment_variables.lua` | Toolkit and Wayland variables, NVIDIA variables when that driver is loaded, cursor (via `sleekshell/cursor.lua`) |
| `modules/monitors.lua` | Loads your `monitors.lua` / `monitors_custom.lua` if present, else uses the preferred mode |
| `modules/decorations.lua`, `layout.lua`, `miscellaneous.lua`, `input.lua`, `window_rules.lua` | Standard Hyprland settings. `decorations.lua` applies `sleekshell/look.lua` (your Settings → Windows values) |
| `sleekshell/bindlayer.lua` | Wraps `hl.bind` so that Settings can disable, move or relabel any bind loaded after it (`hypr-binds.lua`) |
| `modules/keybinds.lua`, `modules/shell_keys.lua` | Default shortcuts ([KEYBINDS.md](KEYBINDS.md)) |
| `custom_binds.lua` | Your binds from Settings → Keyboard (not shipped) |
| `modules/autostart.lua` | quickshell, awww-daemon, the cliphist watchers |
| `modules/workspaces.lua`, `workspace_state.lua` | Independent workspaces per monitor, stored in `~/.local/state/hyprland/workspaces.txt` |
| `user.lua` | Your additions, loaded last (not shipped) |

The shell changes Hyprland live with `hyprctl eval "require('sleekshell.look').apply()"` and similar calls. It never uses
`hyprctl keyword`, so the values survive `hyprctl reload`. `scripts/hypr-tools.py` lists binds and monitors as JSON for
the Settings app.

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
| `assets/wallpapers/` | One MIT wallpaper, copied to `~/Pictures/Wallpapers` if absent ([LICENSE.md](../assets/wallpapers/LICENSE.md)) |
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
| `/etc/greetd/sleek-shell/` | Greeter only: a copy of your look, made at greeter install or `--sync` |
