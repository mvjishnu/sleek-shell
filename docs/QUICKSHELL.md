# Sleek Shell (Quickshell 0.3 on Hyprland 0.56)

Entry point `shell.qml` only composes modules. Reload after edits: `quickshell ipc call reload reload`.

```
services/     singletons (state + logic, no UI)
  Theme.qml     design tokens + theme engine  -> ~/.config/sleek-shell/appearance.json, themes.json, hypr-look.lua
  Settings.qml  shell behaviour               -> ~/.config/sleek-shell/settings.json
  Sys.qml       system state: PipeWire, UPower, power-profiles, BlueZ, NetworkManager, MPRIS, brightness, clipboard
  Notifs.qml    notification server, history, pop-up stack
  Wm.qml        windows / per-monitor workspaces / minimise / MRU (talks to hypr/modules/workspace_state.lua)
  Ui.qml        settings window state, focused screen
  Time.qml      one shared clock (minute precision unless seconds are visible)
  StyleLibrary.qml  font / icon / cursor catalogue + install queue (runs scripts/asset-store.py)
components/   reusable controls, all styled from Theme tokens
modules/
  bar/            Bar (per monitor, widget order from Settings), CenterIsland (clock/OSD/now playing), WorkspaceDots
  panels/         dropdown contents: notifications, clipboard, calendar, appearance, sound, wifi, bluetooth, battery, power
  notifications/  Toasts (stacked pop-ups)
  settings/       SettingsWindow (SUPER+I) + pages/ (appearance, styles = fonts/icons/cursors, motion, bar, windows, wallpaper, notifications, keyboard, displays, about)
  lock/ overview/ monitors/ keybinds/
scripts/      on-demand helpers: bt.py (pairing agent), apply-theme.sh / apply-mode.sh (app theming), clipboard-history.sh,
              desktop-prefs.py (GTK/KDE fonts, icons, cursors), asset-store.py (downloads), rofi-prefs.py, quick-check.sh
```

## IPC (`quickshell ipc call <target> <fn> [args]`)
| target | functions |
|---|---|
| settings | toggle, open PAGE, close |
| panel | toggle NAME (notifications clipboard calendar appearance volume wifi bluetooth battery power), close |
| theme | set KEY VALUE, apply NAME, save NAME, reset, get, toggleMode |
| media | playPause, next, previous |
| osd | brightness, volume |
| lock | lock, test (auto-unlocks after 30 s), unlock |
| overview | toggle, open, close |
| switcher | next, prev, confirm, cancel |
| ws | goto N, move N, next, prev (monitor scoped) |
| monitors / keybinds / appearance | toggle |
| styles | installFont FAMILY, installIcon ID, installCursor ID, installPath PATH_OR_URL, installStarter, status |
| reload | reload |

## Icons
`Glyph { name: "wifi" }` uses Material Symbols Rounded (`Theme.sym`, each entry = [symbol code point, MDI fallback]);
`Glyph { code: Theme.ic.x }` is the legacy Nerd Font path. Glyph centres the em square (symbols) or the ink
bounds (MDI) and snaps the baseline to physical pixels — never add manual offsets to icons.
Bar pills: `BarButton` (single pill) / `Island` (multi-item pill), both drawn by `PillSurface`.

## Fonts, icons & cursors (Settings > Fonts, icons & cursors)
- `scripts/asset-store.py` downloads Google Fonts (cached list, 7-day refresh), curated icon themes and cursor themes,
  or imports a local path / URL (archives are scanned). Fonts -> `~/.local/share/fonts/sleek-shell/`, themes ->
  `~/.local/share/icons/`; manifest `~/.local/share/sleek-shell/assets.json`. No sudo; remove only touches user dirs.
- `scripts/desktop-prefs.py` lists installed fonts/icons/cursors (with previews) and applies them to GTK, Qt/KDE,
  fontconfig and the cursor (gsettings, settings.ini, kcminputrc, icons/default, `hyprctl setcursor`,
  `~/.config/sleek-shell/hypr-cursor.lua` read by `hypr/sleekshell/cursor.lua`).
- Variety pack: `quickshell ipc call styles installStarter` (or `asset-store.py starter`).

## Rules
- Only `Theme` writes appearance files, only `Settings` writes settings.json, only `hypr-tools.py` writes keybinds.
- No polling while idle: system state comes from D-Bus/PipeWire signals; helpers run only when a panel needs them.
- Every duration goes through `Theme.dur()` / `Theme.durFast…` so speed and reduced motion apply everywhere.
- Strokes, separators and shadows use `Theme.strokeWidth/stroke/separator/shadowColor`, so their switches are honoured everywhere.
