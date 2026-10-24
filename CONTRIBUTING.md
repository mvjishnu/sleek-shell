# Contributing

Bug reports, distro reports and pull requests are welcome.

## Reporting a bug

Please include:
- your distribution and the output of `./install.sh --check`;
- the output of `Hyprland --version` and `quickshell --version`;
- what you did, what you expected, and what happened;
- the Quickshell log (see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)).

Before you paste any log or screenshot, remove personal data such as user names, host names, network names and notifications.

**Distro reports are especially useful.** Everything outside Arch is untested, so a report like "it installed and ran on Fedora 42
with these packages" helps everyone.

## Development

```sh
./install.sh --dry-run          # see what an install would do
tests/run.sh                    # every suite except live; none needs root or touches your real config
tests/run.sh live               # read-only checks of the running session
tests/run.sh static installer   # only some suites
SLEEK_KEEP_TMP=1 tests/installer.sh   # keep the temporary homes for inspection
```

The test suites:
| Suite | What it checks |
|---|---|
| `static` | `bash -n` and shellcheck (if installed); `luac`, `qmlformat`, Python and JSON parse; executable bits; `Hyprland --verify-config` on the desktop and greeter configs; `--help` output |
| `hygiene` | no personal paths, names, secrets, symlinks or large files |
| `lua` | Hyprland Lua modules (workspaces, monitors, environment) against a mock `hl` API, plus a paren-call lint |
| `qml` | QML JavaScript logic (idle timeouts, battery set, dimming) with `qmltestrunner`, offscreen |
| `units` | Python unit tests (`hypr-tools.py` shortcut editor) |
| `gpu` | GPU detection and driver plans for every NVIDIA generation, hybrids and kernels, from sysfs fixtures |
| `deps` | dependency table, package hints and `--install-deps` with stubbed package managers |
| `distro` | os-release fixtures for 16 distributions plus a malicious one, init system and display manager detection, package hints |
| `calc` | calculator engine unit tests |
| `app-themes` | theme export rewrites only the generated blocks (needs `jq`) |
| `installer` | install, reinstall, edits, upgrades, `--replace-hypr`, `--profile shell`, uninstall and purge, all in temporary homes |
| `greeter` | greeter install, `--enable` refusals and uninstall against a fake root under `/tmp`, using stub commands |
| `system` | the whole Arch install in a bubblewrap sandbox with a fake root and recording stubs for `sudo`, `pacman`, `systemctl`, `yay`: fresh laptop, Pascal desktop with SDDM, interactive answers, reruns, dry run, failures (needs `bwrap`) |
| `live` | not run by default; inside a running Sleek Shell session only: IPC targets, keybinds and the log (checks the *installed* copy) |

## Guidelines

- Every privileged step goes through `priv`/`priv_write` (`lib/priv.sh`), is recorded with `sys_change`, and is covered
  by `tests/system.sh`. Nothing may need root on other distributions or with `--user-only`.
- The installer runs under `set -euo pipefail`: do not end a function with `[ ... ] && cmd`, and do not write
  assignments whose only command substitution can fail.
- Do not hard-code user names, home paths, monitors or GPUs. Use `$HOME`, XDG variables and detection.
- QML: style everything from `Theme` tokens; services hold state and modules hold UI (see [docs/QUICKSHELL.md](docs/QUICKSHELL.md)).
- Shell scripts: `set -euo pipefail`, quote everything, and keep them shellcheck-clean.
- If a change affects files the installer copies, also update `tests/installer.sh`.
- Add a line to `CHANGELOG.md` under an `Unreleased` heading.

By contributing, you agree that your contribution is licensed under the MIT License.
