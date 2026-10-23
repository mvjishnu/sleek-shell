import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

// SUPER + K / `quickshell ipc call keybinds toggle`: the keybinding manager now lives in
// Settings > Keyboard (one window for all settings). This keeps the shortcut and IPC target working.
Scope {
    GlobalShortcut { name: "keybinds-toggle"; description: "Keyboard shortcuts"; onPressed: Ui.toggleSettings("keyboard") }
    IpcHandler { target: "keybinds"; function toggle(): void { Ui.toggleSettings("keyboard") } }
}
