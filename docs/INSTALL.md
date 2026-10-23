# Installing Sleek Shell

## 1. Dependencies

Sleek Shell does not install packages for you. Run the check, then install what it lists with your package manager:

```sh
./install.sh --check
```

It prints your distribution, init system and display manager, and a table of every dependency with these levels:

- **required**: the shell does not start, or core features break without it.
- **recommended**: a visible feature is missing without it.
- **optional**: one button or panel is missing without it.

At the end it prints the package-manager command it would use (it does not run it). It exits with code 3 when
something required is missing.

The core packages on Arch are:
```sh
sudo pacman -S --needed hyprland quickshell python awww wl-clipboard cliphist rofi fontconfig xdg-utils \
    ttf-jetbrains-mono-nerd wireplumber networkmanager libnotify jq grim slurp kitty inter-font
```

For other distributions, see [DISTROS.md](DISTROS.md). The full table is in `lib/deps.sh`.

Version checks: Hyprland **0.55+** is required (the config is Lua), and Quickshell **0.2+** is required (tested with 0.3.2).
rofi older than 2.0 only gets a warning, because it lacks native Wayland support.

## 2. Preview

```sh
./install.sh --dry-run
```

This shows every file that would be copied, replaced or backed up, and writes nothing.

## 3. Install

```sh
./install.sh                    # full profile: shell + Hyprland config + kitty/rofi defaults + calculator
./install.sh --profile shell    # only the shell; your Hyprland config is not touched
./install.sh --replace-hypr     # replace an existing non-Sleek ~/.config/hypr (it is backed up first)
./install.sh --yes              # do not ask (required when there is no terminal)
./install.sh --ignore-deps      # install even though required dependencies are missing
```

The installer refuses to run as root. It never runs `sudo`, never installs packages, and never enables services or edits `/etc`.

### What goes where

| Path | Profile | Behaviour |
|---|---|---|
| `~/.config/quickshell/` | both | Installed. A non-Sleek config is backed up first. |
| `~/.config/hypr/` | full | See below. |
| `~/.config/rofi/config.rasi`, `themes/rice.rasi` | both | Installed only if absent. |
| `~/.config/kitty/kitty.conf`, `theme.conf`, `font.conf` | full | Installed only if absent. |
| `~/.config/sleek-shell/app-themes.json` | both | Installed only if absent. All your settings live in this folder. |
| `~/.local/bin/sleek-calc`, `~/.local/share/applications/sleek-calc.desktop` | both | Calculator launcher. |
| `~/.local/lib/rofi/calc.so` | both | Calculator plugin, built only if `make` and a C compiler are present. Otherwise script mode is used. |
| `~/.local/share/fonts/sleek-shell/` | both | Material Symbols icon font. |
| `~/.local/share/sleek-shell/` | both | `uninstall.sh`, docs, greeter files, manifest. |

What happens to `~/.config/hypr`:
- **Absent**: Sleek Shell's config is installed.
- **Already Sleek Shell's**: it is upgraded. Your `monitors.lua`, `custom_binds.lua` and `user.lua` are never shipped or overwritten.
- **Your own config**: it is **kept**. The installer tells you the minimum your config needs (see [CONFIG.md](CONFIG.md)).
  Pass `--replace-hypr` to back it up and use Sleek Shell's instead.

### Backups and the manifest

- Anything that is replaced is moved to `~/.local/share/sleek-shell-backups/<timestamp>/`.
- Every installed file is recorded with its SHA-256 in `~/.local/share/sleek-shell/manifest.tsv`.
- Some files are rewritten at runtime by the theme engine (`kitty/theme.conf`, `kitty/font.conf`, `rofi/themes/rice.rasi`,
  `sleek-shell/app-themes.json`). These are recorded as generated files.

## 4. Start it

If you were already in Hyprland, log out and back in, or reload:
```sh
hyprctl reload
pkill -x quickshell; hyprctl dispatch 'hl.dsp.exec_cmd("quickshell")'
```
From a TTY, start Hyprland the usual way (`start-hyprland` or `Hyprland`). You can also use any display manager that lists
the Hyprland session. For a matching login screen, see [GREETER.md](GREETER.md) (optional, needs root).

The installer adds one wallpaper, `~/Pictures/Wallpapers/sleek-shell-astronaut.png`, unless a file with that name
already exists. The uninstaller removes it only if you have not changed it. Put more wallpapers in
`~/Pictures/Wallpapers`, or set `WALLPAPER_DIR`. `SUPER+W` cycles through them.

## Upgrading

Pull the new version and run `./install.sh` again. Files are handled like this:
- **Unchanged installed files**: updated.
- **Installed files you edited**: saved to `<backup>/edited/` and then replaced.
- **Files installed "only if absent"** (kitty, rofi, app themes): kept if you changed them.
- **Files a release no longer ships**: removed if unchanged.

Running it again with no changes does nothing and creates no backups.

## Tested

The installer has been tested on CachyOS, and in temporary homes by `tests/installer.sh`.
Fedora, Debian/Ubuntu and openSUSE are covered only by fixture tests. See [DISTROS.md](DISTROS.md).
