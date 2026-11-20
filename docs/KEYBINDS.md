# Keyboard shortcuts

These are the defaults. `SUPER+K` shows the live list. To rebind or disable any of them without editing files, use
Settings → Keyboard (`SUPER+I`). Your changes are saved in `~/.config/sleek-shell/` and `~/.config/hypr/custom_binds.lua`.

## Applications
| Keys | Action |
|---|---|
| `SUPER` (tap) | App launcher (rofi) |
| `SUPER+T` | Terminal (`kitty --single-instance`) |
| `SUPER+E` | File manager (Thunar) |
| `SUPER+B` | Browser (Zen Browser by default) |
| `SUPER+C` | Clipboard history (rofi) |
| `SUPER+ALT+C` | Calculator & unit converter |

## Shell
| Keys | Action |
|---|---|
| `SUPER+I` | Sleek Shell settings |
| `SUPER+K` | Keyboard shortcuts |
| `SUPER+Tab` | Workspace overview |
| `ALT+Tab` / `ALT+SHIFT+Tab` | App switcher |
| `SUPER+SHIFT+A` | Appearance panel |
| `SUPER+SHIFT+D` | Display settings |
| `SUPER+L` | Lock screen |
| `SUPER+M` | Log out (exit Hyprland) |

## Windows
| Keys | Action |
|---|---|
| `SUPER+Q` | Close window |
| `SUPER+V` | Toggle floating |
| `SUPER+H` | Hide (minimise); restore it from `ALT+Tab` |
| `SUPER+P` | Pseudo-tile |
| `SUPER+J` | Toggle split direction |
| `SUPER+Arrow keys` | Move focus |
| `SUPER+left drag` / `SUPER+right drag` | Move / resize |

## Workspaces (per monitor)
Every monitor has its own workspaces 1–10.
| Keys | Action |
|---|---|
| `SUPER+1`…`SUPER+0` | Go to workspace 1–10 of this monitor |
| `SUPER+SHIFT+1`…`0` | Move window to workspace 1–10 of this monitor |
| `SUPER+X` / `SUPER+Z` | Next / previous workspace |

## Monitors (act on the monitor under the cursor)
Monitors are packed left to right with no gaps whenever one is plugged in or removed; requested modes are checked
against the modes each monitor reports. Order, rotation and mode are kept in `~/.local/state/hypr/monitor-layout.lua`.
| Keys | Action |
|---|---|
| `SUPER+ALT+Left` / `SUPER+ALT+Right` | Move this monitor one place left / right |
| `SUPER+ALT+R` | Rotate this monitor 90° |
| `SUPER+ALT+P` | Reset this monitor (native mode, auto scale, no rotation) |
| `SUPER+ALT+M` | Cycle extend → mirror laptop → external only → laptop only |

## Desktop and media
| Keys | Action |
|---|---|
| `SUPER+W` / `SUPER+SHIFT+W` | Next / previous wallpaper |
| `ALT+S` | Screenshot a region (saved to `~/Pictures/Screenshots` and copied) |
| `ALT+SHIFT+S` | Screenshot the screen |
| Volume, mute, mic mute, brightness, and media keys | As labelled |

While Settings → Keyboard is recording a shortcut, `SUPER+ALT+Escape` leaves the recorder.

## Changing programs

The defaults are the `local` variables at the top of `hypr/modules/keybinds.lua`:

```lua
local terminal    = "kitty --single-instance"
local fileManager = "thunar"
local menu        = "rofi -show drun"
```

Change them there, then reload Hyprland (`hyprctl reload`) or reboot. To rebind keys instead, use
Settings → Keyboard; your changes are written to `~/.config/hypr/custom_binds.lua` and survive upgrades.

The wallpaper folder and transition are in Settings → Wallpaper and stored in
`~/.config/sleek-shell/settings.json`.
