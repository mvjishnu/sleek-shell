# Configuration

Most things are set in the Settings app (`SUPER+I`), and changes apply live. This page covers the files behind it and what you
can change by hand.

## Your settings: `~/.config/sleek-shell/`

The Settings app writes these files. The installer never overwrites them, and the uninstaller keeps them unless you pass `--purge`.

| File | Contents |
|---|---|
| `settings.json` | Shell behaviour: bar widgets, clock, notifications, launcher, lock screen, … |
| `appearance.json`, `themes.json` | Palette, accent, glass, blur, borders, light/dark |
| `app-themes.json` | Which apps follow the theme, and per-app overrides |
| `keybinds.json`, `hypr-binds.lua` | Shortcuts you rebound or disabled |
| `hypr-look.lua`, `hypr-cursor.lua` | Generated for Hyprland from your appearance and cursor settings |
| `theme-export.json` | Generated for `apply-theme.sh` |
| `avatar` | Lock screen and greeter picture (optional) |

To reset everything, quit the shell, move this folder away, and start it again.

## Your Hyprland additions: `~/.config/hypr/user.lua`

Sleek Shell's `hyprland.lua` loads `user.lua` last, if it exists. Put monitor tweaks, extra binds, window rules and
autostart entries there. The installer never ships, overwrites or removes it, so upgrades keep it.

```lua
-- ~/.config/hypr/user.lua
hl.bind("SUPER + F", hl.dsp.exec_cmd("firefox"))
hl.on("hyprland.start", function() hl.exec_cmd("nm-applet") end)
```

If `user.lua` has an error, it is reported with `[sleek-shell] user.lua: …` and the rest of the config still loads.
Check your config with:
```sh
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
```

Other files that are yours and never shipped:
- `monitors.lua` / `monitors_custom.lua`: written by Settings → Displays or by `nwg-displays`.
- `custom_binds.lua`: written by Settings → Keyboard.

## Programs and environment variables

The default programs are set at the top of `hypr/modules/keybinds.lua`:

```lua
local terminal    = "kitty --single-instance"
local fileManager = "thunar"
local menu        = "rofi -show drun"
```

Change them there (or rebind in Settings → Keyboard), then reload Hyprland. The shipped config uses
`$HOME`/`XDG_CONFIG_HOME` for every script path, so it works for any user.

| Variable | Default | Effect |
|---|---|---|
| `WALLPAPER_DIR` | `~/Pictures/Wallpapers` | Folder used by `SUPER+W` and Settings → Wallpaper |
| `AWWW_TRANSITION` | the transition from Settings → Wallpaper | Transition passed to `awww` |
| `PIXEL_LOCK_ON_START` | unset | Set by `~/.zprofile` on an auto-login TTY so `start-shell` requests the PAM lock once |
| `SLEEK_SYS_ROOT` | empty | Test hook: prefix for `/etc` and `/sys` lookups; leave unset normally |

The hybrid-graphics switch in `hypr/modules/env.lua` keeps the desktop on the integrated GPU when the
proprietary NVIDIA driver is loaded; use `prime-run APP` for apps that should render on the NVIDIA GPU.

## Shell profile (zsh)

The reference desktop runs zsh with Powerlevel10k. The installer writes these only when you do not
already have them, so your own shell setup is never replaced:

| File | Contents |
|---|---|
| `~/.zshrc` | Powerlevel10k, history, autosuggestions, syntax highlighting, eza aliases, Rust helper, `~/.zshrc.local` hook |
| `~/.zprofile` | Starts Hyprland on VT1 after an auto-login, with the startup lock flag |
| `~/.p10k.zsh` | The Powerlevel10k prompt configuration |
| `~/.powerlevel10k/` | Powerlevel10k itself, cloned by the installer when missing |

Put personal additions in `~/.zshrc.local`; it is sourced last and never touched. If the prompt is
plain, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md#the-zsh-prompt-is-plain).

## Boot (`/etc`)

The boot experience is system configuration, so it lives outside this repository. `arch_boot_apply` in
`lib/arch.sh` writes it idempotently, backs up every file and rebuilds only when something changed:

| File | Value |
|---|---|
| `/etc/plymouth/plymouthd.conf` | `Theme=lone`, `ShowDelay=0` |
| `/etc/mkinitcpio.conf` | `HOOKS=(… plymouth filesystems plymouth-shutdown)` |
| `/etc/default/grub` | `GRUB_THEME="/usr/share/grub/themes/stylish/theme.txt"`, `quiet splash`, `GRUB_GFXMODE=1920x1080,auto` |

Then `mkinitcpio -P` and `grub-mkconfig -o /boot/grub/grub.cfg` run. On systems without Plymouth or
GRUB the current boot is left alone. Backups go to
`~/.local/share/sleek-shell-backups/<date>/system/`.

## File manager

Thunar is the reference file manager, with `thunar-volman` and `gvfs` for drives, mounts and trash.
The installer sets Thunar as the `inode/directory` handler **only when no handler is configured**, so
an existing choice is kept. Change it with:

```sh
xdg-mime default thunar.desktop inode/directory
```

## App theming

When you change the palette, `quickshell/scripts/apply-theme.sh` (needs `jq`) rewrites **only its own marked blocks** in:

| App | File |
|---|---|
| kitty | `~/.config/kitty/theme.conf` (included from `kitty.conf`) |
| rofi | `~/.config/rofi/themes/rice.rasi` |
| GTK 3/4 | `~/.config/gtk-3.0/gtk.css`, `~/.config/gtk-4.0/gtk.css` |
| Qt/KDE | `~/.config/kdeglobals`, `~/.local/share/color-schemes/Rice.colors` |
| micro | `~/.config/micro/colorschemes/rice.micro` |

Everything else in those files is kept. Each app can be turned off, or given its own palette, in Settings → Appearance → Apps.
Fonts, icons and cursors you pick in Settings → Fonts, icons & cursors are written to GTK (`settings.ini`, `gsettings`),
KDE (`kdeglobals`, `kcminputrc`), Rofi (font in `rice.rasi`, `icon-theme` in `config.rasi`) and
`~/.config/fontconfig/conf.d/50-sleek-shell.conf`. The cursor theme and size are also written to
`~/.config/sleek-shell/hypr-cursor.lua` (read by Hyprland at startup, which exports `XCURSOR_THEME` /
`XCURSOR_SIZE` and `HYPRCURSOR_*`) and applied live with `hyprctl setcursor`. The size is stored in
`settings.json` as `cursorSize`, so it survives Quickshell restarts and reboots.

If you keep your own `kitty.conf` or rofi `config.rasi`, the installer does not replace it. To follow the theme, add
`include theme.conf` (kitty) or `@theme "~/.config/rofi/themes/rice.rasi"` (rofi).

## Using your own Hyprland config

`./install.sh` keeps an existing non-Sleek `~/.config/hypr`. You can also use `--profile shell`. The shell then needs at least the following.

In a Lua config:
```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
hl.bind("SUPER + I",         hl.dsp.global("quickshell:settings-toggle"))
hl.bind("SUPER + Tab",       hl.dsp.global("quickshell:overview-toggle"))
hl.bind("ALT + Tab",         hl.dsp.global("quickshell:switcher-next"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.global("quickshell:switcher-prev"))
hl.bind("SUPER + K",         hl.dsp.global("quickshell:keybinds-toggle"))
hl.bind("SUPER + H",         hl.dsp.global("quickshell:minimize"))
hl.bind("SUPER + L",         hl.dsp.exec_cmd("quickshell ipc call lock lock"))
```

In a classic `hyprland.conf`:
```ini
exec-once = quickshell
exec-once = awww-daemon
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
bind = SUPER, I, global, quickshell:settings-toggle
bind = SUPER, Tab, global, quickshell:overview-toggle
bind = ALT, Tab, global, quickshell:switcher-next
bind = SUPER, L, exec, quickshell ipc call lock lock
```

Also start a polkit agent, or apps that need admin rights cannot ask for your password. On Arch, add
`exec-once = /usr/lib/hyprpolkitagent/hyprpolkitagent` (or `hl.exec_cmd(...)` in Lua). Sleek Shell's own config uses
`scripts/polkit-agent`, which picks whichever agent is installed (see [DEPENDENCIES.md](DEPENDENCIES.md)).

Some features need Sleek Shell's Lua modules and are **not available** with your own config:
- rebinding in Settings → Keyboard;
- live window looks (borders, blur, gaps, animations);
- cursor sync;
- independent per-monitor workspaces.

A reference copy of Sleek Shell's config is installed in `~/.local/share/sleek-shell/hypr/`. You can borrow modules from it.

## The shell itself

The installer manages `~/.config/quickshell/`. Your edits are saved to the backup folder and replaced at the next upgrade
(see [INSTALL.md](INSTALL.md#upgrading)). To change the shell itself, fork the repository. Internals are described in
[QUICKSHELL.md](QUICKSHELL.md) and [ARCHITECTURE.md](ARCHITECTURE.md).
