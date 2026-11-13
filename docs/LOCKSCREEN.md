# Lock screen

The lock screen is a Pixel-inspired session lock. Your wallpaper sits under a configurable
blur and shade, with a large clock, the date and one password capsule. It is deliberately calm:
there is no spinning animation, only a short fade when the surface appears.

## What it does

- **One password field.** The capsule is drawn on the monitor that was focused when the session
  locked. If you start typing on another monitor, it moves there with a 120 ms fade. The password
  is never echoed, logged or written to disk.
- **Fade in, not a show.** The lock surface fades in over 220 ms with an `OutCubic` curve, so the
  desktop does not flash. When Settings → Motion turns animations off, the fade is instant.
- **Clock.** Five styles: digital, analog, dots, flip and the compact variant. The clock is
  refreshed at lock time and its timer only runs while the session is locked.
- **PAM.** Authentication uses the system `login` PAM service (`config: "login"` in
  `modules/pixel/PixelLock.qml`). There is no bypass path; a wrong password shakes the field.
- **Idle.** Built in, no `hypridle` needed. Settings → Lock screen sets when the session locks,
  turns the screen off and suspends, how long it dims first (30 s by default; any input brings it
  back), and a separate, shorter set on battery. `quickshell ipc call idle status` prints the
  timeouts in effect right now.

The visual files live in `quickshell/modules/pixel/`:

| File | Role |
|---|---|
| `PixelLock.qml` | PAM session lock, password handling, lock/unlock entry points |
| `PixelLockSurface.qml` | One surface per monitor |
| `LockView.qml` | Wallpaper, blur, shade, clock, date and password capsule |
| `LockClock.qml` | Clock style switch |
| `LockClockDigital.qml`, `LockClockAnalog.qml`, `LockClockDots.qml`, `LockClockFlip.qml` | Clock styles |
| `DotDigit.qml` | Dot-matrix digits |
| `modules/lock/IdleGuard.qml` | Idle dim → lock → screen off → suspend and logind integration |

## Use

- Safe test (unlocks itself after 30 s): `quickshell ipc call lock test`
- Real lock: `quickshell ipc call lock lock`, or Power menu → Lock
- Keybind: `SUPER+L`
- Visual test helpers (only while `lock test` is up, never touch PAM):
  `quickshell ipc call lock testType 6`, `quickshell ipc call lock testFail`
- Settings: **Settings → Lock screen** for clock style, wallpaper blur/shade, the lock wallpaper
  and the idle timeouts.

## Needs

- `grim` for the blurred background capture (package `grim` on every supported distribution).
- Quickshell already running, with the files above next to `shell.qml`.

## If you get stuck

Run the safe test first. If a real lock ever hangs or the screen shows a "lockscreen died" message:

1. Switch to a TTY (Ctrl+Alt+F3) and log in.
2. Run `hyprctl --instance 0 eval 'hl.config({ misc = { allow_session_lock_restore = true } })'`.
3. Restart the lock with
   `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("qs ipc call lock lock")'`.
4. Go back to your session (Ctrl+Alt+F1 or F2). As a last resort, `loginctl terminate-user $USER`
   ends the session.

## Notes

- Escape or Ctrl+U clears what you typed.
- The lock screen keeps its own style mode; palette colours are copied once per lock, so changing
  the theme while locked does not repaint the surface under you.
- The startup lock after TTY1 auto-login is requested once by `hypr/scripts/start-shell`; reloading
  the shell never re-locks an unlocked session.
