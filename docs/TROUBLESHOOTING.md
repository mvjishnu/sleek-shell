# Troubleshooting

Start with:
```sh
cat ~/.local/share/sleek-shell/install-report.txt      # what the installer changed and checked
./install.sh --check                                   # missing dependencies and versions
~/.config/quickshell/scripts/quick-check.sh            # commands, backlight devices, monitor names
quickshell log                                          # log of the running shell
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
```

## The installer
- **"not a terminal"**: it was started without a terminal (a pipe, a script). Add `--yes` to take the defaults.
- **"run as your own user, not root"**: run it as your normal user; it asks for `sudo` itself.
- **"systemd is not running (a chroot?)"**: boot into the installed system first, then run it again.
- **pacman failed**: usually the network, mirrors or keyring. Fix that (`sudo pacman -Syu` shows the error) and run
  `./install.sh` again; nothing is installed twice.
- **An AUR package failed**: the rest is installed. Retry it with `yay -S PACKAGE`.
- **Exit status 4**: installed, but a check failed. The `FAIL` lines in the report say which one.
- **It stopped half way**: run it again. Finished steps are skipped.

## Black screen or no picture after login (NVIDIA)
- Check `cat /sys/module/nvidia_drm/parameters/modeset` prints `Y`. If not, the initramfs was not rebuilt:
  `sudo mkinitcpio -P` (or `sudo dracut --regenerate-all --force`), then reboot. With booster, rebuild it yourself.
- Hybrid laptops run the desktop on the integrated GPU. Start a program on the NVIDIA GPU with `prime-run APP`.
- No picture after suspend: `systemctl is-enabled nvidia-suspend nvidia-resume` should print `enabled` twice.

## No sound
- `wpctl status` should list your outputs. If it fails, `systemctl --user enable --now pipewire.socket
  pipewire-pulse.socket wireplumber.service`.
- Laptops with Intel audio need `sof-firmware` (installed on Arch) and a reboot.

## No network after the reboot
The installer hands the network to NetworkManager. If you used systemd-networkd or dhcpcd, they were disabled; see
`~/.local/share/sleek-shell/system-changes.log`. Connect with `nmtui`, or switch back with
`sudo systemctl disable NetworkManager && sudo systemctl enable systemd-networkd`.

## A terminal asks zsh configuration questions
That is zsh's first-run wizard: `~/.zshrc` is missing. Run `./install.sh` again (it installs one), or press `q`.

## The bar does not appear
- Check that Quickshell is running: `pgrep -x quickshell`. If it is not, start it from a terminal inside Hyprland with
  `quickshell`. QML errors are printed there.
- `module "Quickshell.…" is not installed` means your Quickshell is too old or was built without that module. Use 0.2 or newer
  (tested with 0.3.2).
- If you use your own Hyprland config, it must start `quickshell` itself. See [CONFIG.md](CONFIG.md#using-your-own-hyprland-config).

## Hyprland shows a config error banner
- Run `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua` to see the error.
- An error in your `user.lua` is reported as `[sleek-shell] user.lua: …`. The rest of the config still loads.
- Hyprland older than 0.55 cannot read the Lua config. Check `Hyprland --version`.

## Shortcuts do nothing
- `SUPER+I`, `SUPER+Tab`, `ALT+Tab`, `SUPER+K` and `SUPER+H` are Quickshell global shortcuts. They work only while the shell runs.
- Check Settings → Keyboard for a disabled or rebound shortcut. `SUPER+K` lists what is active.
- `SUPER+T`, `SUPER+E` and `SUPER+B` launch `$SLEEK_TERMINAL`, `$SLEEK_FILE_MANAGER` and `$SLEEK_BROWSER`, falling back to
  kitty and your default apps. Set a default with `xdg-mime default <app>.desktop inode/directory`, or with
  `xdg-settings set default-web-browser <app>.desktop`.

## Wallpaper
`SUPER+W` shows a notification when it cannot work:
- "Wallpaper folder not found" or "No wallpapers found": put images in `~/Pictures/Wallpapers` or set `WALLPAPER_DIR`.
- "Wallpaper daemon not running": start `awww-daemon`. Sleek Shell's config autostarts it.

## Clipboard history is empty
`SUPER+C` needs both `wl-paste --watch cliphist store` watchers. Sleek Shell's config starts them. With your own config,
add them (see [CONFIG.md](CONFIG.md#using-your-own-hyprland-config)).

## Apps do not follow the theme
- Install `jq`. Without it, `apply-theme.sh` skips the theme export.
- Check that the app is turned on in Settings → Appearance → Apps.
- If you kept your own `kitty.conf` or rofi config, it must include Sleek Shell's theme file. See [CONFIG.md](CONFIG.md#app-theming).
- GTK 4 and Qt apps read the theme when they start, so restart them.

## Power menu or idle suspend does nothing
These call `systemctl suspend|reboot|poweroff` and need systemd/logind with permission for your session (the default on
desktop distributions). Without systemd, see [DISTROS.md](DISTROS.md#without-systemd). Test it with `systemctl suspend`
from a terminal.

## Wi-Fi, Bluetooth, volume or brightness panels are empty
These need `nmcli` (NetworkManager), `bluetoothctl` plus `python-gobject`, `wpctl` (WirePlumber) and `brightnessctl`.
`quick-check.sh` and `./install.sh --check` show which ones are missing.

## Icons show as boxes or letters
The Material Symbols font is installed into `~/.local/share/fonts/sleek-shell/`. Run `fc-cache -f`, then restart the shell
(`pkill -x quickshell; quickshell &`). The bar also needs the JetBrains Mono Nerd Font.

## Restart the shell
```sh
pkill -x quickshell; hyprctl dispatch 'hl.dsp.exec_cmd("quickshell")'
```

## Reporting a bug
Include:
- the output of `./install.sh --check`;
- your Hyprland and Quickshell versions;
- the relevant part of `quickshell log`.

From a repository checkout you can also run `python3 tests/logcheck.py`. It prints only the warnings and errors since the
shell last loaded, without known-harmless Qt noise.

Remove anything personal from the log before posting it. It can contain window titles and paths.

## Login greeter
See [GREETER.md](GREETER.md#recovery). A text login is always available on `Ctrl+Alt+F2`…`F6`.
