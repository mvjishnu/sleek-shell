# Installing Sleek Shell

## Before you start

You need a booted Arch Linux (or Arch-based: CachyOS, EndeavourOS, Manjaro, Garuda, ...) system with systemd,
a working network connection, and a normal user that can use `sudo`. A minimal `archinstall` profile is enough;
no desktop, display manager or graphics driver is needed.

If your user cannot use `sudo` yet, as root:
```sh
pacman -S --needed sudo git
usermod -aG wheel YOUR_USER
EDITOR=nano visudo        # uncomment: %wheel ALL=(ALL:ALL) ALL
```
Log in again as that user. Do not run the installer as root, or inside `arch-chroot` before the first boot: it
installs into your home and needs a running systemd. It refuses both and says why.

## The install

Clone the repository (the URL is in the [README](../README.md#install)), then from the checkout:
```sh
./install.sh
```

### 1. What it finds

The installer prints the distribution, init system, current login screen, every graphics card (with the driver
it will use) and whether the system part can run. Then it checks every dependency (see
[DEPENDENCIES.md](DEPENDENCIES.md)). Nothing has changed yet.

### 2. The choices

Only choices that depend on you are asked. Press Enter to take the default, or type a number or the name.

| Question | When | Default | Option |
|---|---|---|---|
| Web browser | always on Arch | the browser you already use, else Firefox | `--browser firefox\|chromium\|vivaldi\|brave\|zen\|chrome\|epiphany\|none` |
| Replace the current login screen? | only when another display manager is enabled | no (keep it) | `--greeter auto\|sleek\|keep` |
| When you are away | always | Balanced, or your current timeouts on a reinstall | `--idle short\|balanced\|long\|never` |

- **Browser:** packages that are not in your repositories (Google Chrome; Brave and Zen outside CachyOS) are
  built from the AUR, and the list says so. The browser you pick becomes the default for web links.
  `none` installs nothing and keeps your current default.
- **Login screen:**
  - With no display manager, the [Sleek Shell greeter](GREETER.md) is installed and enabled for the next boot.
    `--greeter keep` skips it; you then start Hyprland from the console with `start-hyprland`.
  - With another display manager, it is kept unless you say yes (or pass `--greeter sleek`). Replacing disables
    the old one; it is not removed, and the report shows the command that switches back.
  - With the Sleek Shell greeter already running, it is refreshed.
- **Idle:** minutes until the screen locks, turns off, and the system suspends. Suspend applies only to
  laptops (a battery is present); on desktops it stays off.

  | Preset | Lock | Screen off | Suspend (laptops) |
  |---|---|---|---|
  | Short | 5 | 10 | 15 |
  | Balanced | 10 | 15 | 30 |
  | Long | 15 | 30 | 60 |
  | Never | never | never | never |

  Exact values: `--lock-after`, `--screen-off-after`, `--suspend-after` (minutes, `0` = never). You can change
  all of them later in Settings → Lock screen.

### 3. The plan

Before changing anything it prints the plan: the packages from the repositories and the AUR, packages it
removes (PulseAudio, when PipeWire replaces it), the graphics driver, the services, the login screen, the
browser, the login shell, and every path in your home it installs, upgrades, replaces or keeps. Then it asks
**Install now?** once. `--yes` answers yes and takes the defaults above; with no terminal and no `--yes` it stops.

### 4. System setup (sudo)

`sudo` asks for your password once; the installer keeps the ticket alive until it finishes.

1. **Packages.** The distribution keyrings are refreshed, conflicting audio packages are removed, then
   `pacman -Syu --needed` upgrades the system and installs everything in one transaction. Already installed
   packages are skipped. If pacman fails, the installer stops here and nothing else is changed.
2. **AUR.** Only when something needs it (the 580xx NVIDIA driver, some browsers). If neither yay nor paru is
   installed, `yay-bin` is built first, as you, never as root. An AUR failure is a warning: the rest still installs.
3. **Graphics.**
   - AMD and Intel: Mesa, Vulkan and video decoding.
   - NVIDIA Turing (GTX 16xx, RTX 20xx) and newer: the open kernel modules (`nvidia-open`, or `-lts` / `-dkms`
     to match your kernels), `nvidia-utils`, `libva-nvidia-driver`.
   - NVIDIA Pascal and Maxwell (GTX 9xx/10xx): `nvidia-580xx-dkms` from the AUR (the last driver for them).
   - Older NVIDIA cards, or `--nvidia nouveau`: Mesa's nouveau.
   - With NVIDIA it writes `/etc/modprobe.d/sleek-shell-nvidia.conf` (kernel mode setting, video memory kept
     across suspend) only for options that are not set already, rebuilds the initramfs (mkinitcpio or dracut),
     and enables `nvidia-suspend`, `nvidia-resume` and `nvidia-hibernate`.
   - Hybrid laptops (NVIDIA plus an integrated GPU) get `nvidia-prime`: the desktop runs on the integrated GPU
     and `prime-run APP` uses the NVIDIA one. No global NVIDIA environment variables are set, so the
     NVIDIA GPU can sleep.
4. **Your home** (step 5 below).
5. **Login screen**, as chosen.
6. **Services.**
   - PipeWire, PipeWire-Pulse and WirePlumber: enabled as user services for every user.
   - NetworkManager: enabled. If systemd-networkd, dhcpcd, connman or netctl manage the network now, they are
     disabled (not stopped) and NetworkManager takes over after the reboot, so the connection you install over keeps
     working. If iwd is enabled, NetworkManager is set to use it for Wi-Fi.
   - Bluetooth and power-profiles-daemon: enabled and started. power-profiles-daemon is not installed when
     tuned, TLP or auto-cpufreq is installed.
7. **Login shell:** zsh, only when your shell is still bash. A shell you picked yourself is kept;
   `--keep-shell` keeps bash.
8. **Home folders:** `xdg-user-dirs-update` creates Documents, Downloads, Pictures, ... if they do not exist.

### 5. Your home

| Path | Behaviour |
|---|---|
| `~/.config/quickshell/` | Installed. A non-Sleek config is backed up first. |
| `~/.config/hypr/` | See below. Profile `full` only. |
| `~/.zshrc` | Installed when you have none, or when it only holds the comments zsh's first-run wizard wrote. Yours is kept. Personal additions can go in `~/.zshrc.local`. |
| `~/.config/rofi/config.rasi`, `themes/rice.rasi` | Installed only if absent. |
| `~/.config/kitty/kitty.conf`, `theme.conf`, `font.conf` | Installed only if absent. Profile `full` only. |
| `~/.config/sleek-shell/` | `app-themes.json` only if absent; `settings.json` gets the idle timeouts. All your settings live here. |
| `~/.local/bin/sleek-calc`, `~/.local/share/applications/sleek-calc.desktop` | Calculator launcher. |
| `~/.local/lib/rofi/calc.so` | Calculator plugin, built when `make` and a C compiler are present; otherwise script mode is used. |
| `~/.local/share/fonts/sleek-shell/` | Material Symbols icon font. |
| `~/Pictures/Wallpapers/sleek-shell-astronaut.png` | Default wallpaper, unless a file with that name exists. |
| `~/.local/share/sleek-shell/` | `uninstall.sh`, docs, greeter files, manifest, report. |

What happens to `~/.config/hypr`:
- **Absent**, or only the config Hyprland generated on its first start: Sleek Shell's config is installed (an
  autogenerated one is backed up first).
- **Already Sleek Shell's**: upgraded. Your `monitors.lua`, `monitors_custom.lua`, `custom_binds.lua` and `user.lua`
  are never shipped or overwritten.
- **Your own config**: **kept**. The installer tells you the minimum your config needs (see [CONFIG.md](CONFIG.md)).
  Pass `--replace-hypr` to back it up and use Sleek Shell's instead.

The installed config is checked with `Hyprland --verify-config`. It also:
- puts `~/.local/bin` on `PATH` for the session (and the zsh config does for terminals);
- scales built-in laptop panels between 1920 and 2560 pixels wide to 1.25 when that gives a whole-pixel desktop
  (1920×1080 → 1536×864); other outputs use Hyprland's automatic scale. Settings → Displays overrides it;
- sets `XDG_MENU_PREFIX=arch-` when `archlinux-xdg-menu` is installed, so "Open with" lists work in Dolphin and
  other KDE apps.

### 6. Verification and the report

At the end the installer checks what a working desktop needs after the reboot: every package installed,
Hyprland and Quickshell present, the PipeWire, NetworkManager, Bluetooth and power services enabled, the Nerd
Font installed, the NVIDIA options and suspend services, the login shell, greetd running the Sleek Shell greeter
(when chosen) and the Hyprland config. It writes:

| File | Contents |
|---|---|
| `~/.local/share/sleek-shell/install-report.txt` | distro, graphics, choices, every system change, every check, warning count |
| `~/.local/share/sleek-shell/system-changes.log` | every system change, appended on each run, with how to undo it |
| `~/.local/share/sleek-shell/manifest.tsv` | every installed file with its SHA-256 |

Then reboot: `systemctl reboot`.

### Exit status

| Code | Meaning |
|---|---|
| 0 | Installed (or `--check`: nothing required is missing) |
| 1 | Error: nothing more was changed after it (the message says what failed and how to retry) |
| 3 | `--check`: required programs are missing |
| 4 | Installed, but a check failed: see the report and [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| 130 | Interrupted |

If the install stops half way (an error, Ctrl+C, a lost connection), run `./install.sh` again: finished steps are
skipped.

## All options

| Option | Effect |
|---|---|
| `--dry-run`, `-n` | Print the whole plan and every `sudo` command it would run; change nothing |
| `--check` | Report the system, the dependencies and the plan; change nothing |
| `--yes`, `-y` | Take the default for every choice and do not ask (keeps an existing display manager) |
| `--browser ID` | See the choices above |
| `--greeter auto\|sleek\|keep` | See the choices above |
| `--idle PRESET`, `--lock-after MIN`, `--screen-off-after MIN`, `--suspend-after MIN` | See the choices above |
| `--nvidia open\|580xx\|nouveau` | Override the NVIDIA driver picked from the card |
| `--profile full\|shell` | `shell`: only the Quickshell shell; your Hyprland config, kitty and zsh are not touched |
| `--replace-hypr` | Replace an existing non-Sleek `~/.config/hypr` (backed up first) |
| `--keep-shell` | Do not change the login shell |
| `--user-only`, `--skip-system` | No `sudo`: install into your home only (the old behaviour) |
| `--ignore-deps` | With `--user-only` or on other distributions: install the files even when required programs are missing |
| `--install-deps`, `--with-optional` | Other distributions: install the missing packages after asking (see [DISTROS.md](DISTROS.md)) |
| `--help`, `-h` | Print the options |

## Other distributions

On Fedora, openSUSE, Debian and Ubuntu (and on Arch with `--user-only`) only your home is changed. The installer
lists the missing packages and the command to install them; `--install-deps` runs it after you confirm, using only
your distribution's repositories. It prints the services to enable, and never enables them. The greeter is then
installed separately with `sudo ~/.local/share/sleek-shell/greeter/install.sh` (see [GREETER.md](GREETER.md)).
See [DISTROS.md](DISTROS.md).

## Starting it

After the reboot, log in on the Sleek Shell greeter (or your display manager, choosing the Hyprland session).
Without a display manager, log in on the console and run `start-hyprland`.

If you reinstall from inside Hyprland, restart the shell instead:
```sh
pkill -x quickshell; hyprctl dispatch 'hl.dsp.exec_cmd("quickshell")'
```

## Upgrading

Pull the new version and run `./install.sh` again. Installed packages, enabled services and existing settings are
left as they are; your previous choices are offered as the defaults. Files are handled like this:
- **Unchanged installed files**: updated.
- **Installed files you edited**: saved to `<backup>/edited/` and then replaced.
- **Files installed "only if absent"** (kitty, rofi, app themes, zshrc): kept if you changed them.
- **Files a release no longer ships**: removed if unchanged.

Running it again with no changes creates no backups.

## How it is tested

- **Real installs:** CachyOS, used daily.
- **Fresh Arch, simulated end to end** (`tests/system.sh`): the installer runs in a bubblewrap sandbox with a fake
  root filesystem and recording stubs for `sudo`, `pacman`, `systemctl`, `yay`, `makepkg` and `git`. Covered: a hybrid
  NVIDIA laptop, a Pascal desktop with SDDM, PulseAudio and tuned, an AMD laptop answering every question, reruns,
  dry runs, refusing without a terminal, and failures of pacman, the AUR, a service and the greeter.
- **GPU plans** (`tests/gpu.sh`): every NVIDIA generation, hybrids, kernel flavours, existing modprobe options.
- **Home installs** (`tests/installer.sh`), the greeter (`tests/greeter.sh`), other distributions (`tests/distro.sh`,
  `tests/deps.sh`), the Hyprland Lua modules (`tests/lua.sh`).

Run everything with `tests/run.sh`. No test needs root or changes the machine it runs on.
