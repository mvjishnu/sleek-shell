import QtQuick
import QtQuick.Layouts
import qs.services

// Inline password prompt used by the Wi-Fi menu when a network needs a key.
// The key goes to NetworkManager over D-Bus (WifiNetwork.connectWithPsk); it never touches a
// command line, a log or a state file, and the field is cleared as soon as it is submitted.
Rectangle {
    id: p
    property string ssid: ""
    property string note: ""
    property bool reveal: false
    signal submit(string value)
    signal cancel()

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 24
    radius: Theme.controlRadius
    antialiasing: true
    color: Theme.surface
    border.width: Theme.strokeWidth
    border.color: entry.activeFocus ? Qt.alpha(Theme.accent, 0.6) : Theme.stroke
    visible: ssid !== ""

    function focusEntry() { entry.forceActiveFocus() }
    function send() { if (entry.text.length === 0) return; var v = entry.text; entry.text = ""; p.reveal = false; p.submit(v) }
    onVisibleChanged: { entry.text = ""; reveal = false; if (visible) focusTimer.restart(); else { focusTimer.stop(); entry.focus = false } }
    onSsidChanged: if (visible) { entry.text = ""; focusTimer.restart() }
    // the window gets keyboard focus a frame after it maps; ask again until the field has it
    Timer { id: focusTimer; interval: 40; repeat: true; property int tries: 0
            onTriggered: { entry.forceActiveFocus(); if (entry.activeFocus || ++tries > 12) { stop(); tries = 0 } } }

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: 12 }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Glyph { code: Theme.ic.lock; color: Theme.accent; size: 14; implicitWidth: 16; implicitHeight: 16 }
            Text {
                text: "Password for " + p.ssid
                color: Theme.text
                font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold
                elide: Text.ElideRight; Layout.fillWidth: true
            }
        }
        Text {
            visible: p.note !== ""
            text: p.note
            color: Theme.yellow
            font.family: Theme.font; font.pixelSize: Theme.fontSm
            wrapMode: Text.WordWrap; Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            radius: Theme.smallRadius
            antialiasing: true
            color: Theme.track
            border.width: entry.activeFocus ? 2 : 0
            border.color: Theme.accent
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 4 }
                spacing: 2
                TextInput {
                    id: entry
                    objectName: "wifiPasswordField"
                    Layout.fillWidth: true
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: p.reveal ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    maximumLength: 63
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    font.family: Theme.font; font.pixelSize: Theme.fontLg
                    clip: true
                    onAccepted: p.send()
                    onActiveFocusChanged: Ui.dbgEntryFocus = activeFocus && Window.active
                    Window.onActiveChanged: Ui.dbgEntryFocus = activeFocus && Window.active
                    Keys.onEscapePressed: e => { p.cancel(); e.accepted = true }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: entry.text === ""
                        text: "Enter password"
                        color: Theme.dim
                        font.family: Theme.font; font.pixelSize: Theme.fontLg
                    }
                }
                IconButton { code: p.reveal ? Theme.ic.eyeOff : Theme.ic.eye; boxSize: 30; tooltip: p.reveal ? "Hide password" : "Show password"; onClicked: { p.reveal = !p.reveal; entry.forceActiveFocus() } }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "Enter to connect · Esc to cancel"; color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm; Layout.fillWidth: true; elide: Text.ElideRight }
            UiBtn { label: "Cancel"; onClicked: p.cancel() }
            UiBtn { label: "Connect"; selected: true; enabled: entry.text.length >= 8; onClicked: p.send() }
        }
    }
}
