# Quickshell lock screen

The lock screen uses the same design as the Sleek Shell greeter: your wallpaper
blurred under a palette-tinted scrim, a large clock in the UI font (12/24 h from Settings), one glass card
(padlock badge, your real name, notification count, capsule password field with a go button), now-playing
controls when media is active, and status (Wi-Fi, battery) plus suspend / restart / shut down at the bottom right.
The card is on the focused monitor; other monitors show the clock with a small padlock. Reduced motion
(Settings › Motion) skips the animation. Colours are copied from the theme once per lock.
Visual test helpers (only while `lock test` is up, never touch PAM): `quickshell ipc call lock testType 6`,
`quickshell ipc call lock testFail`. Power buttons do nothing in test mode.


A padlock drops out of the bar's clock pill, spinning, lands in the middle and clicks shut,
then the glass grows out of it into the lock screen. Unlocking plays it backwards: the shackle pops open and the
lock flies back up into the bar. A wrong password shakes the field and wobbles the lock.
Colour and frost follow the theme chosen from the palette icon in the bar.
Every typed character shows a PlayStation symbol in turn: triangle, circle, cross, square.

## Needs
- `grim` (screenshot used for the blurred background; package `grim` on every supported distro)
- Quickshell already running (the bar), with these files next to shell.qml:
  modules/lock/ (Lock, LockScene, LockStyle, LockSurface, PsSymbol).

## Use
- Safe test (unlocks itself after 30 s): `quickshell ipc call lock test`
- Real lock: `quickshell ipc call lock lock`, or Power menu > Lock in the bar.
- Keybind example: `quickshell ipc call lock lock`
- Idle: built in, no hypridle needed. Settings > Lock screen sets when the screen locks, turns off and the system
  suspends, how long the screen dims first (30 s by default; any input brings it back), and on laptops a separate,
  shorter set used on battery. `quickshell ipc call idle status` prints the timeouts in effect right now.

## If you get stuck
Run the safe test first. If a real lock ever hangs or the screen shows a "lockscreen died" message:
1. Switch to a TTY (Ctrl+Alt+F3) and log in.
2. Run: `hyprctl --instance 0 eval 'hl.config({ misc = { allow_session_lock_restore = true } })'`  (Hyprland 0.56 uses the Lua config; `keyword` no longer exists)
3. Either restart the lock with `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("qs ipc call lock lock")'`, or,
   if you keep `hyprlock` installed as a fallback, start it the same way and unlock it with your password.
4. Go back to your session (Ctrl+Alt+F1 or F2). As a last resort, `loginctl terminate-user $USER` ends the session.

## Notes
- Password checking uses PAM service "login" (see `config:` in modules/lock/Lock.qml). The password is never logged.
- The lock screen deliberately keeps its own style (LockStyle.qml) and copies palette colours once per lock.
- Escape or Ctrl+U clears what you typed.
