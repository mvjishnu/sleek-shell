# Keyboard shortcuts

These are the defaults. `SUPER+K` shows the live list. To rebind or disable any of them without editing files, use
Settings → Keyboard (`SUPER+I`). Your changes are saved in `~/.config/sleek-shell/` and `~/.config/hypr/custom_binds.lua`.

## Applications
| Keys | Action |
|---|---|
| `SUPER` (tap) | App launcher (rofi) |
| `SUPER+T` | Terminal (`$SLEEK_TERMINAL`, default `kitty`) |
| `SUPER+E` | File manager (`$SLEEK_FILE_MANAGER`, default: your desktop's default) |
| `SUPER+B` | Browser (`$SLEEK_BROWSER`, default: your desktop's default) |
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

## Desktop and media
| Keys | Action |
|---|---|
| `SUPER+W` / `SUPER+SHIFT+W` | Next / previous wallpaper |
| `ALT+S` | Screenshot a region (saved to `~/Pictures/Screenshots` and copied) |
| `ALT+SHIFT+S` | Screenshot the screen |
| Volume, mute, mic mute, brightness, and media keys | As labelled |

While Settings → Keyboard is recording a shortcut, `SUPER+ALT+Escape` leaves the recorder.

## Changing programs

Hyprland reads these variables at startup. Put them where your login sets the environment:
- greetd, including the Sleek Shell greeter, reads `~/.profile`.
- A TTY login reads your shell's login file: `~/.bash_profile` (or `~/.profile`) for bash, `~/.zprofile` for zsh.
```sh
export SLEEK_TERMINAL=foot
export SLEEK_FILE_MANAGER=nautilus
export SLEEK_BROWSER=firefox
```
Log in again afterwards. To rebind keys instead, use Settings → Keyboard.
