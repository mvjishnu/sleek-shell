# Uninstalling Sleek Shell

```sh
~/.local/share/sleek-shell/uninstall.sh --dry-run   # show what would happen
~/.local/share/sleek-shell/uninstall.sh             # remove and restore (asks first)
~/.local/share/sleek-shell/uninstall.sh --purge     # also remove your Sleek Shell settings and downloaded fonts
```

Options: `--dry-run`/`-n`, `--purge`, `--yes`/`-y` (required when there is no terminal), `--keep-greeter`, `--help`.
It refuses to run as root, and it never uses `sudo` or removes packages.

## What it does

1. **Removes installed files.** Only files listed in the manifest are removed, and only if they are unchanged since install.
   Files you edited are kept and listed at the end. Generated files (`kitty/theme.conf`, `kitty/font.conf`,
   `rofi/themes/rice.rasi`, `sleek-shell/app-themes.json`) are always removed, because the theme engine rewrites them.
2. **Removes the folders it created**, if they are now empty.
3. **Restores backups.** Everything the installer moved away is put back from `~/.local/share/sleek-shell-backups/<timestamp>/`.
   A backup is restored only if nothing exists at its original path now.

Kept unless you pass `--purge`:
- `~/.config/sleek-shell/` (your settings, themes, keybind changes, avatar)
- `~/.local/share/fonts/sleek-shell/`
- `~/.local/share/sleek-shell/assets.json`
- `~/.local/state/hyprland/workspaces.txt`
- `~/.local/state/awww-rice/`

Never removed:
- your `monitors.lua`, `custom_binds.lua` and `user.lua`;
- the backup folder;
- fonts, icon themes or cursors you downloaded in Settings into `~/.local/share/fonts` or `~/.local/share/icons`.

Also left as they are: the colour blocks that app theming wrote into `~/.config/gtk-3.0/gtk.css`, `gtk-4.0/gtk.css`,
`~/.config/kdeglobals` and `~/.config/micro/colorschemes/rice.micro`. Delete those blocks by hand if you want them gone.

## System changes

On Arch, `install.sh` also installed packages, enabled services, wrote NVIDIA options and possibly changed your
login shell and display manager. The uninstaller does not undo these (it never uses `sudo`), but it prints the list
from `~/.local/share/sleek-shell/system-changes.log`, which also shows how to undo each one. Packages you no longer
want can be removed with `sudo pacman -Rns PACKAGE`.

## The login greeter

If the greeter is installed (`/etc/greetd/sleek-shell` exists), the uninstaller refuses to run. Removing the desktop
would leave a login screen that starts a session with no shell. Roll the greeter back first:

```sh
sudo ~/.local/share/sleek-shell/greeter/uninstall.sh   # then reboot
```

Or pass `--keep-greeter` if you really want to keep it. See [GREETER.md](GREETER.md).

## While Hyprland is running

Hyprland reloads `~/.config/hypr` whenever it changes. If you uninstall from inside a Sleek Shell session, expect a
config error banner until your previous config is restored or you log out. The uninstaller warns you about this.
Log out once it has finished.
