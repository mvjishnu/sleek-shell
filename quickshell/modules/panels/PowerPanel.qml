import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// Full-screen session chooser. Power actions require a second click so the
// spacious tiles remain safe to use accidentally.
PanelWindow {
    id: pp
    required property var targetScreen

    readonly property bool open: Sys.openPopup === "power" && Sys.openScreen === targetScreen.name
    property string armed: ""
    property int countdown: 0
    readonly property int confirmSecs: 4

    screen: targetScreen
    visible: open
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-power"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        armed = ""
        if (open) focusTimer.restart()
    }

    Timer { id: focusTimer; interval: 35; onTriggered: focusScope.forceActiveFocus() }
    Timer {
        id: tick
        interval: 1000
        repeat: true
        running: pp.armed !== ""
        onTriggered: if (--pp.countdown <= 0) pp.armed = ""
    }

    function act(id, needsConfirm, fn) {
        if (needsConfirm && armed !== id) {
            armed = id
            countdown = confirmSecs
            tick.restart()
            return
        }
        armed = ""
        Sys.close()
        fn()
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: pp.open
        Keys.onEscapePressed: { Sys.close(); event.accepted = true }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha("#07080b", 0.88)
        }
        MouseArea { anchors.fill: parent; onClicked: Sys.close() }

        GridLayout {
            id: actions
            anchors.fill: parent
            anchors.margins: Math.max(18, Math.min(parent.width, parent.height) * 0.035)
            columns: 3
            columnSpacing: Math.max(10, Math.min(parent.width, parent.height) * 0.018)
            rowSpacing: Math.max(10, Math.min(parent.width, parent.height) * 0.022)

            Repeater {
                model: [
                    { id: "lock", code: Theme.ic.lock, accent: Theme.accent, title: "Lock", confirm: false },
                    { id: "logout", code: Theme.ic.logout, accent: Theme.cyan, title: "Logout", confirm: true },
                    { id: "suspend", code: Theme.ic.suspend, accent: Theme.blue, title: "Suspend", confirm: true },
                    { id: "hibernate", code: Theme.ic.moon, accent: Theme.purple, title: "Hibernate", confirm: true },
                    { id: "poweroff", code: Theme.ic.power, accent: Theme.red, title: "Shutdown", confirm: true },
                    { id: "reboot", code: Theme.ic.restart, accent: Theme.purple, title: "Reboot", confirm: true }
                ]
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool isArmed: pp.armed === modelData.id
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    Layout.minimumHeight: 0
                    radius: 22
                    antialiasing: true
                    color: isArmed ? Qt.alpha(modelData.accent, 0.34)
                         : (mouse.containsMouse ? Qt.alpha(modelData.accent, 0.82) : "#1b1c20")
                    border.width: Theme.shellBorders ? 1 : 0
                    border.color: isArmed || mouse.containsMouse ? modelData.accent : Qt.alpha("#dce3e9", 0.09)
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: isArmed ? "Confirm " + modelData.title : modelData.title
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            tile.activate()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            Sys.close()
                            event.accepted = true
                        }
                    }

                    function activate() {
                        pp.act(modelData.id, modelData.confirm, function () {
                            switch (modelData.id) {
                            case "lock": Sys.later(function () { Sys.lockRequested() }, 260); break
                            case "logout": Sys.run(["hyprctl", "dispatch", "hl.dsp.exit()"]); break
                            case "suspend": Sys.run(["systemctl", "suspend"]); break
                            case "hibernate": Sys.run(["systemctl", "hibernate"]); break
                            case "poweroff": Sys.run(["systemctl", "poweroff"]); break
                            case "reboot": Sys.run(["systemctl", "reboot"]); break
                            }
                        })
                    }

                    Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
                    Behavior on radius { enabled: Theme.animations; NumberAnimation { duration: Theme.durFast } }
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Math.max(10, Math.min(22, tile.height * 0.045))
                        Glyph {
                            Layout.alignment: Qt.AlignHCenter
                            code: tile.modelData.code
                            size: Math.max(28, Math.min(58, tile.height * 0.20))
                            color: mouse.containsMouse ? Theme.onAccent : "#d8c9ff"
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.isArmed ? "Confirm " + tile.modelData.title + "?" : tile.modelData.title
                            color: mouse.containsMouse ? Theme.onAccent : Theme.text
                            font.family: Theme.font
                            font.pixelSize: Math.max(12, Math.min(17, tile.height * 0.055))
                            font.weight: Font.Medium
                        }
                        Text {
                            visible: tile.isArmed
                            Layout.alignment: Qt.AlignHCenter
                            text: pp.countdown + "s · click again"
                            color: mouse.containsMouse ? Qt.alpha(Theme.onAccent, 0.8) : Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { tile.forceActiveFocus(); tile.activate() }
                    }
                }
            }
        }
    }
}
