# Security

## Reporting a vulnerability

Please do **not** open a public issue for security problems. Use GitHub's private vulnerability reporting
("Security" tab → "Report a vulnerability") on this repository. Include steps to reproduce and the affected version.
I will try to respond within a week.

Only the latest release is supported.

## Security-relevant parts

| Part | Notes |
|---|---|
| Lock screen | Authenticates through PAM with Quickshell's `WlSessionLock`. If the shell crashes while locked, Hyprland keeps the session locked. |
| Greeter | Runs as the unprivileged greeter account under greetd. greetd and the distro's `/etc/pam.d/greetd` handle authentication; Sleek Shell does not change PAM. Passwords are cleared right after they are sent and are never stored or logged. |
| Greeter installer | Runs as root and installs `greetd` (and the Inter font) with the system package manager. It reads files from your home **as you** (`runuser`), so symlinks cannot pull root-only files into the world-readable `/etc/greetd/sleek-shell`. It checks configs with `Hyprland --verify-config` before using them, and backs up `/etc/greetd/config.toml`. |
| Desktop installer | Per-user. It refuses to run as root and never calls `sudo`. |
| Calculator | A hand-written tokenizer and parser. Input never reaches `eval`, `exec` or a shell. |
| Clipboard history | Stored by `cliphist` in your home. It can contain secrets you copied. Clear it from the clipboard panel. |
| Asset downloads | Settings → Fonts, icons & cursors downloads fonts, icon and cursor themes over HTTPS into `~/.local/share`. It only does this when you ask. |
