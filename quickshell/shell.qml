import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.modules.bar
import qs.modules.notifications
import qs.modules.pixel
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
    id: root
    property bool splashVisible: false

    IpcHandler {
        target: "health"
        function ready(): string { return "ok" }
    }
    IpcHandler {
        target: "startupSplash"
        function show(): void {
            root.splashVisible = true
            splashTimer.restart()
        }
    }

    Timer {
        id: splashTimer
        interval: 2400
        onTriggered: root.splashVisible = false
    }
    IpcHandler {
        target: "reload"
        function reload(): void {
            if (pixelLock.locked) {
                console.warn("Reload skipped while the session is locked; unlock first to keep the lock surface alive")
                return
            }
            Quickshell.reload(true)
        }
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

    PixelLock { id: pixelLock }
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
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            visible: root.splashVisible
            color: "#ed090d18"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-startup"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}

            Item {
                anchors.fill: parent
                Rectangle {
                    id: halo
                    width: 210; height: 210; radius: width / 2
                    anchors.centerIn: parent
                    color: "transparent"
                    border.width: 1
                    border.color: "#554bdcff"
                    opacity: 0.65
                    SequentialAnimation on scale {
                        running: root.splashVisible
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.12; duration: 950; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 950; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on opacity {
                        running: root.splashVisible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 950 }
                        NumberAnimation { to: 0.65; duration: 950 }
                    }
                }

                Rectangle {
                    width: 126; height: 126; radius: width / 2
                    anchors.centerIn: parent
                    color: "#171d2b"
                    border.width: 1
                    border.color: "#704bdcff"
                    Rectangle {
                        width: 48; height: 48; radius: width / 2
                        anchors.centerIn: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#65e4ff" }
                            GradientStop { position: 1; color: "#8c65ff" }
                        }
                        SequentialAnimation on scale {
                            running: root.splashVisible
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.18; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                        }
                    }
                    Item {
                        width: 126; height: 126
                        anchors.centerIn: parent
                        RotationAnimator on rotation {
                            running: root.splashVisible
                            from: 0; to: 360; duration: 1800
                            loops: Animation.Infinite
                        }
                        Rectangle { width: 8; height: 8; radius: 4; x: parent.width / 2 - 4; y: -5; color: "#9b8cff" }
                    }
                }

                Column {
                    anchors { top: parent.verticalCenter; topMargin: 132; horizontalCenter: parent.horizontalCenter }
                    spacing: 9
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "SYSTEM STARTING"
                        color: "#f4f6ff"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        font.letterSpacing: 3
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Getting your workspace ready"
                        color: "#929bb2"
                        font.pixelSize: 12
                    }
                    Item {
                        width: 100; height: 3
                        anchors.horizontalCenter: parent.horizontalCenter
                        Rectangle { anchors.fill: parent; radius: 2; color: "#283044" }
                        Rectangle {
                            height: parent.height; width: 28; radius: 2; color: "#6ddcff"
                            SequentialAnimation on x {
                                running: root.splashVisible
                                loops: Animation.Infinite
                                NumberAnimation { from: 0; to: 72; duration: 650; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 72; to: 0; duration: 650; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
            }
        }
    }
    Toasts {}
}
