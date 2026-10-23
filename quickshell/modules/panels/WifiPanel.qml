import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

ColumnLayout {
    Layout.fillWidth: true
    spacing: Theme.dropdownGap

    Heading {
        title: "Wi-Fi"
        subtitle: !Sys.wifiOn ? "Off" : (Sys.wifiBusy ? "Connecting to " + Sys.wifiTargetName + "…" : (Sys.ssid !== "" ? "Connected to " + Sys.ssid : (Sys.wifiScanning ? "Scanning…" : (Sys.wiredConnected ? "Using wired connection" : "Not connected"))))
        IconButton { visible: Sys.wifiOn; code: Theme.ic.refresh; tooltip: "Scan"; color: Sys.wifiScanning ? Theme.cyan : Theme.muted; enabled: !Sys.wifiScanning; onClicked: Sys.rescanWifi() }
        Toggle { checked: Sys.wifiOn; accent: Theme.cyan; accessibleName: "Wi-Fi"; onToggled: Sys.toggleWifi() }
    }
    Divider {}
    Text {
        visible: Sys.wifiMsg !== "" && !Sys.wifiBusy
        Layout.fillWidth: true
        Layout.leftMargin: 4
        text: Sys.wifiMsg
        color: Sys.wifiMsgOk ? Theme.green : Theme.red
        font.family: Theme.font; font.pixelSize: Theme.fontSm
        wrapMode: Text.WordWrap
    }
    PasswordPrompt {
        ssid: Sys.wifiPending
        note: Sys.wifiPendingNote
        onSubmit: value => Sys.submitWifiPassword(value)
        onCancel: Sys.cancelWifiPassword()
    }
    ListView {
        id: wList
        visible: Sys.wifiOn && Sys.wifiList.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 320)
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: Sys.wifiList
        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property bool connecting: Sys.wifiBusy && Sys.wifiTargetName === modelData.ssid
            width: wList.width
            implicitHeight: 50
            radius: Theme.controlRadius
            antialiasing: true
            color: modelData.active ? Qt.alpha(Theme.cyan, 0.16) : (rowHover.hovered ? Theme.surface : "transparent")
            Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
            HoverHandler { id: rowHover }
            SignalBars {
                id: wBars
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                level: modelData.signal
                color: modelData.signal > 66 ? Theme.cyan : (modelData.signal > 33 ? Theme.blue : Theme.muted)
            }
            Column {
                anchors { left: wBars.right; leftMargin: 12; right: wTrail.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 1
                Text { text: modelData.ssid; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontLg; font.weight: modelData.active ? Font.DemiBold : Font.Normal; elide: Text.ElideRight; width: parent.width }
                Row {
                    spacing: 6
                    Text {
                        text: row.connecting ? "Connecting…" : (modelData.active ? "Connected" : (modelData.signal + "% · " + (modelData.known ? "saved" : (modelData.secure ? (modelData.enterprise ? "enterprise" : "secured") : "open"))))
                        color: modelData.active || row.connecting ? Theme.cyan : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm
                    }
                    Glyph { code: modelData.active ? Theme.ic.check : (modelData.secure ? Theme.ic.lock : 0); color: modelData.active ? Theme.cyan : Theme.dim; size: 12; implicitWidth: 14; implicitHeight: 14 }
                }
            }
            Row {
                id: wTrail
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                spacing: 2
                z: 2
                IconButton { visible: modelData.known && rowHover.hovered && !row.connecting; code: Theme.ic.trash; boxSize: 28; tooltip: "Forget " + modelData.ssid; hoverColor: Theme.red; onClicked: Sys.forgetWifi(modelData.ssid) }
                Text { visible: modelData.active; anchors.verticalCenter: parent.verticalCenter; rightPadding: 6; text: "Disconnect"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm }
            }
            MouseArea {
                id: wMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: !Sys.wifiBusy
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData.active) Sys.disconnectWifi()
                    else Sys.connectWifi(modelData.ssid)
                }
            }
        }
    }
    Empty { visible: !Sys.wifiOn; code: Theme.ic.wifiOff; title: "Wi-Fi is off"; hint: "Turn it on to see networks" }
    Empty { visible: Sys.wifiOn && Sys.wifiScanning && Sys.wifiList.length === 0; code: Theme.ic.refresh; title: "Scanning…"; hint: "Looking for nearby networks" }
    Empty { visible: Sys.wifiOn && !Sys.wifiScanning && Sys.wifiList.length === 0; code: Theme.ic.wifi; title: "No networks found"; hint: "Press the refresh icon to scan again" }
    ActionRow { code: Theme.ic.cog; accent: Theme.muted; title: "Network settings"; subtitle: "nm-connection-editor"; onClicked: { Sys.close(); Sys.run(["sh", "-c", "command -v nm-connection-editor >/dev/null && exec nm-connection-editor || exec kitty -e nmtui"]) } }
}
