import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.bar
import qs.modules.notifications
import qs.modules.lock
import qs.modules.overview
import qs.modules.keybinds
import qs.modules.monitors
import qs.modules.settings

// Sleek Shell (Quickshell 0.3.x on Hyprland). Composition only:
//   services/    singletons: Theme (design system + theme engine), Settings, Sys (system state),
//                Notifs, Wm (windows/workspaces), Ui, Time
//   components/  reusable controls built on Theme tokens
//   modules/     bar, panels, notifications, lock, overview, keybinds, monitors, settings
// Reload after editing:  quickshell ipc call reload reload
ShellRoot {
    IpcHandler {
        target: "reload"
        function reload(): void { Quickshell.reload(true) }
    }
    IpcHandler {
        target: "panel"
        // quickshell ipc call panel toggle wifi   (notifications clipboard calendar appearance volume wifi bluetooth battery power)
        function toggle(name: string): void { var s = Ui.focusedScreen(); if (s) Sys.toggle(name, s.name) }
        function close(): void { Sys.close() }
    }
    IpcHandler {
        target: "appearance"
        function toggle(): void { var s = Ui.focusedScreen(); if (s) Sys.toggle("appearance", s.name) }
    }

    // make sure the long-lived services exist from the start (notification server, theme sync)
    readonly property var _boot: [Theme.loaded, Settings.loaded, Notifs.history, Sys.audioReady, StyleLibrary.busy]

    Lock {}
    Overview {}
    Switcher {}
    WsControl {}
    MonitorSettings {}
    KeybindManager {}
    SettingsWindow {}

    Variants {
        model: Quickshell.screens
        Bar {}
    }
    Toasts {}
}
