# Sleek Shell greeter (optional)

A login screen for [greetd](https://sr.ht/~kennylevinsen/greetd/), built with Quickshell. It runs in its own minimal
Hyprland as the unprivileged greeter account, separate from your desktop shell. Authentication is done entirely by
greetd and PAM.

**This is the only part of Sleek Shell that needs root.** It installs a package and writes to `/etc`. Read this page and
the script (`greeter/install.sh`) before running it. The desktop works without it, with any display manager or from a TTY.

> Configs and backups made under the old project names (`sleakos`, `sleak-shell`) are still recognised.

## Features
- **Look**: your palette and accent, plus a blurred copy of your current wallpaper (copied at install). Without one, it uses
  Hyprland's default wallpaper, or a plain gradient.
- **Clock**: shown in your 12/24 h preference.
- **Users**: every user in the regular uid range (`UID_MIN`–`UID_MAX` from `/etc/login.defs`, default 1000–60000) who has a
  login shell. Switch with ↑/↓.
- **Sessions**: every installed Wayland session, Hyprland first. Cycle with F2 or a click. The last choice is remembered in
  `/var/cache/sleek-shell-greeter/last.json`.
- **Password field**: cleared as soon as it is sent, never stored or logged. Multi-step PAM prompts (for example OTP) appear
  in the same field. A wrong password shakes the card and shows a message.
- **Power**: suspend, restart and shut down.
- **Monitors**: the login card goes on the focused monitor and a clock on the others. Your monitor layout and scales are copied
  from `monitors.lua`.
- **Keyboard**: the system keyboard layout (`localectl`, else `us`). Everything works from the keyboard, with accessible names.

Nothing in PAM is changed (`/etc/pam.d/greetd` comes from your distro's greetd package). The desktop session never runs as root.

## Requirements
- systemd;
- greetd (the installer installs it);
- Hyprland 0.55 or newer;
- Quickshell 0.3 or newer, built with the Greetd service.

The installer:
- installs greetd and the Inter font with pacman, dnf, apt or zypper;
- detects the greeter account (`greeter`, `_greetd` or `greetd`);
- runs the greeter compositor through `start-hyprland` when it exists.

The greeter runs as the greeter account, so it sees only **system** fonts. If Inter cannot be installed, it falls back to
Noto Sans. Fonts in `~/.local/share/fonts` are not visible to it.

After login, greetd starts your session through `/bin/sh`. That reads only `/etc/profile` and `~/.profile`, not
`~/.bashrc`, `~/.bash_profile` or zsh files. Put environment variables the desktop needs in `~/.profile`, for example
`~/.local/bin` on `PATH`, `QT_QPA_PLATFORMTHEME` and `SLEEK_TERMINAL`.

## Install
Install Sleek Shell first (`./install.sh`). Then, from the repository (or from `~/.local/share/sleek-shell/greeter/`):
```sh
sudo ./greeter/install.sh          # installs and verifies; how you log in is unchanged
sudo ./greeter/install.sh --test   # prints the safe test below
sudo ./greeter/install.sh --enable # greeter from the next boot (asks first; does not start it now)
sudo ./greeter/install.sh --sync   # after you change theme, wallpaper, monitors, avatar or keyboard layout
```

How it behaves:
- **A plain install never changes how you log in.** It writes `/etc/greetd/sleek-shell/`, `/etc/greetd/sleek-shell.toml`
  and `/etc/greetd/sleek-shell-test.toml`. If the distro's greetd package enables `greetd.service`, the installer disables it
  again. If the package started greetd, it warns but does not stop it.
- **It never starts or stops greetd.** `greetd.service` takes over tty1, so starting it while you are logged in there would
  end that login. `--enable` takes effect at the next boot.
- **`--enable`**:
  - Replaces an existing `/etc/greetd/config.toml` only after you type `enable` (or pass `--yes`). The old file is first kept as
    `config.toml.pre-sleek-shell-<timestamp>`.
  - Records whether greetd was enabled before, so the uninstaller can restore exactly that.
  - Refuses if another display manager (sddm, gdm, lightdm, ly, …) is enabled or running, or if logind has no TTY fallback
    (`NAutoVTs=0`). It never disables your current display manager for you.
- **Files from your home are read as you** (via `runuser`), never as root: theme, wallpaper, avatar, `monitors.lua`, and only
  the `clock24h` setting. A symlink in your home therefore cannot copy a root-only file into the world-readable
  `/etc/greetd/sleek-shell`.
- **Checked before use.** The generated config is checked with `Hyprland --verify-config` as the greeter account before any
  greetd config points at it. If the check fails, the previous files are put back.

### Safe test
This runs greetd as a transient system service on VT7. greetd stays disabled, and nothing persists:
```sh
sudo systemd-run --unit=sleek-greeter-test --collect -p KeyringMode=shared -p IgnoreSIGPIPE=no -p SendSIGHUP=yes \
    /usr/bin/greetd --config /etc/greetd/sleek-shell-test.toml
sudo systemctl stop sleek-greeter-test       # stop it
journalctl -b -u sleek-greeter-test          # logs
```
Logging in there starts a second, separate session. `Ctrl+Alt+F<n>` returns to your original VT.

Do **not** run `sudo greetd …` from a terminal. greetd would then run inside your existing logind session and get no
`XDG_RUNTIME_DIR`, so the greeter's Hyprland aborts (`XDG_RUNTIME_DIR is not set!`). The real `greetd.service`, and the
`systemd-run` command above, are not affected.

Preview the UI inside your session (mock login, nothing is authenticated):
```sh
quickshell -p ~/.local/share/sleek-shell/greeter/quickshell   # type "preview" to simulate success; Esc quits
```

## Recovery
- A text login is always available on `Ctrl+Alt+F2`…`F6` (logind autovt; `--enable` refuses to run without it).
- If the greeter misbehaves, `Ctrl+Alt+BackSpace` restarts it (greetd relaunches it).
- To go back, run `sudo ./greeter/uninstall.sh [--purge]` and reboot.
  - It restores the newest `config.toml.pre-sleek-shell-*` backup, unless `config.toml` is no longer Sleek Shell's.
  - It returns greetd to its previous enabled or disabled state.
  - It never stops a running greetd. `--purge` (which removes `/etc/greetd/sleek-shell` and the cache) refuses while greetd
    is running.

Uninstall the greeter before the desktop. `uninstall.sh` refuses to run while the greeter is installed.

## Lock screen vs greeter
The lock screen (`SUPER+L`) locks your running session. The greeter is the login screen before any session exists. They
share the look, not the code or the process. See [LOCKSCREEN.md](LOCKSCREEN.md).

## Tested
- **Verified on CachyOS (Arch)**:
  - install;
  - the VT7 test service with real PAM authentication;
  - login to a Hyprland session and logout back to the greeter;
  - the real `greetd.service` after `--enable` and a reboot;
  - rollback.
- **Simulated** (`tests/greeter.sh`, a fake root with stubbed `systemctl`, `runuser`, `greetd` and `localectl`; no package is installed):
  - install and `--enable`, including every refusal;
  - what is copied from your home, and skipping symlinks;
  - rollback on a config that fails verification;
  - the uninstall restore, keep-enabled and purge paths.
- **Not tested**: the dnf, apt and zypper paths, and real installs on Fedora, Debian/Ubuntu and openSUSE; power actions
  as the greeter account on other distributions.
