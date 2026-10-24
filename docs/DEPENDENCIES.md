# Dependencies

This is the full list from `lib/deps.sh`, which is what `./install.sh --check` reads. The installer itself
checks the same table, so this page and the installer cannot disagree.

**Levels:**
- **required**: the shell does not start, or a core feature breaks. `install.sh` stops (exit 3) unless
  you pass `--ignore-deps`.
- **recommended**: a visible feature is missing.
- **optional**: one button or panel is missing, or there is a fallback.

**What gets installed:**
- **Arch and derivatives:** `./install.sh` installs every required, recommended and optional package in
  this table, plus the system packages below, with one `pacman -Syu --needed` (see [INSTALL.md](INSTALL.md)).
  `./install.sh --check` lists them without installing anything.
- **Other distributions** (and `--user-only`): `./install.sh` never installs packages. It prints the command.
  `./install.sh --install-deps` installs missing **required and recommended** packages from your
  distribution's own repositories. `--with-optional` adds the optional ones.
  - It shows the exact command first and runs it only after you type `y`. `--yes` does not answer this
    question, and with no terminal the answer is no.
  - It uses your package manager's own prompt (no `--noconfirm` or `-y`).
  - It refuses to install a display manager.
- Packages in parentheses come from a third-party repository or backports. They are **never** installed
  for you. The installer names the repository, and you decide whether to add it.
- _not packaged_: you have to build it or install it by hand (see [DISTROS.md](DISTROS.md)).

**System packages added on Arch** (`ARCH_BASE_PKGS` in `lib/arch.sh`): PipeWire (`pipewire`, `pipewire-alsa`,
`pipewire-pulse`, `wireplumber`) and `sof-firmware`, NetworkManager, BlueZ, `upower`, `polkit`, the portals,
`gvfs`, `xdg-user-dirs`, `archlinux-xdg-menu`, zsh with completions, autosuggestions and syntax highlighting,
Noto fonts with emoji, Mesa plus Vulkan and video drivers for the detected GPUs, the NVIDIA driver when needed (see
[INSTALL.md](INSTALL.md#4-system-setup-sudo)), the browser you chose, greetd when the Sleek Shell greeter is
installed, and `base-devel` only when something comes from the AUR. PulseAudio is removed when present, because
PipeWire replaces it.

**How the names were checked:**
- **Arch:** every name resolves with `pacman -Sp` against the official repositories (verified on CachyOS).
- **Other columns:** taken from each distribution's package index, not installed. Treat them as simulated
  until someone reports a real install.

The **v0.1.0** column shows what the first release did with each row. v0.1.0 installed none of these
packages: it only printed a command, and rows marked _not checked_ were missing from that command too.

| Component | Used for | Level | Arch | Fedora | Debian / Ubuntu | openSUSE TW | v0.1.0 |
|---|---|---|---|---|---|---|---|
| hyprland | compositor (0.55+ for the Lua config) | required | `hyprland` | `hyprland` (COPR sdegler/hyprland) | `hyprland` (Debian 13: trixie-backports; Ubuntu: PPA cppiber/hyprland) | `hyprland` | checked, names changed |
| quickshell | the shell itself | required | `quickshell` | `quickshell` | `quickshell` (Debian 13: trixie-backports; Ubuntu: PPA avengemedia/danklinux) | `quickshell` (OBS home:AvengeMedia:danklinux) | checked, names changed |
| python | helper scripts | required | `python` | `python3` | `python3` | `python3` | checked |
| awww | wallpaper daemon | required | `awww` | _not packaged_ | `awww` (Ubuntu: PPA razvanalex/hyprland-ppa; Debian: build from source) | `awww` | checked, names changed |
| wl-clipboard | clipboard | required | `wl-clipboard` | `wl-clipboard` | `wl-clipboard` | `wl-clipboard` | checked |
| cliphist | clipboard history | required | `cliphist` | `cliphist` | `cliphist` | `cliphist` | checked |
| rofi | launcher and calculator (2.0+ for Wayland; Debian 13 ships 1.7.5) | required | `rofi` | `rofi` | `rofi` | `rofi` | checked, names changed |
| fontconfig | icon font registration | required | `fontconfig` | `fontconfig` | `fontconfig` | `fontconfig` | checked |
| xdg-utils | default apps | required | `xdg-utils` | `xdg-utils` | `xdg-utils` | `xdg-utils` | checked |
| nerd-font | bar, kitty, rofi and greeter glyphs | required | `ttf-jetbrains-mono-nerd` | _not packaged_ | _not packaged_ | _not packaged_ | checked |
| kitty | default terminal (SUPER+T; override with SLEEK_TERMINAL) | recommended | `kitty` | `kitty` | `kitty` | `kitty` | checked |
| file-manager | file manager for SUPER+E (any; Dolphin is suggested when you have none) | recommended | `dolphin` | `dolphin` | `dolphin` | `dolphin` | **not checked** |
| portal-hyprland | screen sharing and screenshots for apps (XDG portal) | recommended | `xdg-desktop-portal-hyprland` | `xdg-desktop-portal-hyprland` (COPR sdegler/hyprland) | `xdg-desktop-portal-hyprland` (Debian 13: trixie-backports) | `xdg-desktop-portal-hyprland` | **not checked** |
| portal-gtk | file chooser and settings portal | recommended | `xdg-desktop-portal-gtk` | `xdg-desktop-portal-gtk` | `xdg-desktop-portal-gtk` | `xdg-desktop-portal-gtk` | **not checked** |
| polkit-agent | password prompts when an app needs admin rights | recommended | `hyprpolkitagent` | `polkit-kde` | `polkit-kde-agent-1` | `hyprpolkitagent` | **not checked** |
| wireplumber | audio (PipeWire session manager, volume keys) | recommended | `wireplumber` | `wireplumber` | `wireplumber` | `wireplumber` | checked |
| upower | battery widget and panel | recommended | `upower` | `upower` | `upower` | `upower` | **not checked** |
| networkmanager | Wi-Fi panel | recommended | `networkmanager` | `NetworkManager` | `network-manager` | `NetworkManager` | checked |
| libnotify | script notifications | recommended | `libnotify` | `libnotify` | `libnotify-bin` | `libnotify-tools` | checked |
| gdbus | lock the screen before suspend (listens to logind) | recommended | `glib2` | `glib2` | `libglib2.0-bin` | `glib2-tools` | **not checked** |
| jq | theme export to kitty, rofi, GTK, Qt, micro (skipped without it) | recommended | `jq` | `jq` | `jq` | `jq` | checked |
| grim | screenshots, lock screen background | recommended | `grim` | `grim` | `grim` | `grim` | checked |
| slurp | region screenshots | recommended | `slurp` | `slurp` | `slurp` | `slurp` | checked |
| inter-font | UI font (falls back to Noto Sans) | recommended | `inter-font` | `rsms-inter-fonts` | `fonts-inter` | `inter-fonts` | checked, names changed |
| noto-font | default app font and UI fallback | recommended | `noto-fonts` | `google-noto-sans-fonts` | `fonts-noto-core` | `google-noto-sans-fonts` | **not checked** |
| papirus | default icon theme | recommended | `papirus-icon-theme` | `papirus-icon-theme` | `papirus-icon-theme` | `papirus-icon-theme` | **not checked** |
| cursor | default cursor theme | recommended | `adwaita-cursors` | `adwaita-cursor-theme` | `adwaita-icon-theme` | `adwaita-icon-theme` | **not checked** |
| brightnessctl | backlight keys and slider | optional | `brightnessctl` | `brightnessctl` | `brightnessctl` | `brightnessctl` | checked |
| playerctl | media keys (fall back to the shell) | optional | `playerctl` | `playerctl` | `playerctl` | `playerctl` | checked |
| bluez | Bluetooth panel | optional | `bluez-utils` | `bluez` | `bluez` | `bluez` | checked |
| blueman | "Bluetooth settings" button | optional | `blueman` | `blueman` | `blueman` | `blueman` | **not checked** |
| gobject | Bluetooth panel helper | optional | `python-gobject` | `python3-gobject` | `python3-gi` | `python3-gobject` | checked |
| nm-editor | "Network settings" button (falls back to nmtui in kitty) | optional | `nm-connection-editor` | `nm-connection-editor` | `nm-connection-editor` | `NetworkManager-connection-editor` | **not checked** |
| power-profiles | power profile switch | optional | `power-profiles-daemon` | `power-profiles-daemon` | `power-profiles-daemon` | `power-profiles-daemon` | checked |
| pipewire-pulse | PulseAudio apps and pavucontrol | optional | `pipewire-pulse` | `pipewire-pulseaudio` | `pipewire-pulse` | `pipewire-pulseaudio` | **not checked** |
| pavucontrol | "More audio settings" button | optional | `pavucontrol` | `pavucontrol` | `pavucontrol` | `pavucontrol` | checked |
| gsettings | GTK font/icon settings | optional | `glib2` | `glib2` | `libglib2.0-bin` | `glib2-tools` | checked |
| kwriteconfig6 | Qt/KDE font/icon settings | optional | `kconfig` | `kf6-kconfig` | `libkf6config-bin` | `kf6-kconfig` | checked |
| gtk-launch | open default browser/file manager | optional | `gtk3` | `gtk3` | `libgtk-3-bin` | `gtk3-tools` | checked |
| nwg-displays | monitor layout editor | optional | `nwg-displays` | _not packaged_ | `nwg-displays` | `nwg-displays` | checked, names changed |
| imagemagick | icon theme previews | optional | `imagemagick` | `ImageMagick` | `imagemagick` | `ImageMagick` | checked |
| qt-imageformats | WebP wallpaper previews | optional | `qt6-imageformats` | `qt6-qtimageformats` | `qt6-image-formats-plugins` | `qt6-imageformats` | **not checked** |
| bsdtar | unpacking downloaded fonts, icons and cursors | optional | `libarchive` | `bsdtar` | `libarchive-tools` | `bsdtar` | **not checked** |
| pciutils | GPU line in the system info | optional | `pciutils` | `pciutils` | `pciutils` | `pciutils` | **not checked** |
| curl | weather, asset downloads | optional | `curl` | `curl` | `curl` | `curl` | checked |
| calc-build | faster calculator plugin (falls back to script mode) | optional | `base-devel` | `make gcc rofi-devel` | `build-essential` | `make gcc rofi-devel` | checked |

## Services

On Arch, `./install.sh` enables these and checks them at the end. On other distributions it only warns
about each one that is installed but not running, and prints the command to start it:

| Service | Scope | Needed for |
|---|---|---|
| `NetworkManager.service` | system | Wi-Fi panel |
| `bluetooth.service` | system | Bluetooth panel |
| `power-profiles-daemon.service` | system | power profile switch (not installed when tuned, TLP or auto-cpufreq is) |
| `pipewire.socket`, `pipewire-pulse.socket`, `wireplumber.service` | user (enabled globally) | audio and volume keys |
| `nvidia-suspend`, `nvidia-resume`, `nvidia-hibernate` | system | NVIDIA only: picture after suspend |
| `greetd.service` | system | the Sleek Shell greeter, when chosen |

It also warns if another notification daemon (mako, dunst, swaync, fnott, xfce4-notifyd) is running.
That daemon would take notifications away from the shell.

## Started by the Hyprland config

`hypr/modules/autostart.lua` starts these at login. Each one is covered by a row above, except
`dbus-update-activation-environment`, which is part of dbus and present on every systemd system:
- `quickshell`
- `awww-daemon`
- `wl-paste --watch cliphist store` (text and images)
- `hypr/scripts/polkit-agent.sh`: starts the first polkit agent it finds (hyprpolkitagent, polkit-kde,
  polkit-gnome, mate-polkit, lxqt or lxpolkit). It does nothing if one is already running, for example
  under a full desktop session.

## Login greeter

Needed for [GREETER.md](GREETER.md). On Arch `./install.sh` installs these; elsewhere
`sudo greeter/install.sh` installs them with your package manager's own prompt:

| Component | Arch | Fedora | Debian / Ubuntu | openSUSE |
|---|---|---|---|---|
| greetd | `greetd` | `greetd` | `greetd` | `greetd` |
| Inter (system-wide) | `inter-font` | `rsms-inter-fonts` | `fonts-inter` | `inter-fonts` |
| JetBrainsMono Nerd Font (system-wide) | `ttf-jetbrains-mono-nerd` | by hand | by hand | by hand |

The greeter also needs Quickshell 0.3+ built with its Greetd service. The greeter account cannot read
fonts in your home directory, so the Nerd Font must be in `/usr/share/fonts` or `/usr/local/share/fonts`.
