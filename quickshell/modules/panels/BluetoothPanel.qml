import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

ColumnLayout {
    id: bt
    Layout.fillWidth: true
    spacing: Theme.dropdownGap
    readonly property var paired: Sys.btList.filter(function (d) { return d.paired || d.connected })
    readonly property var found: Sys.btList.filter(function (d) { return !d.paired && !d.connected && d.name !== d.mac })

    Heading {
        title: "Bluetooth"
        subtitle: !Sys.btAvailable ? "No adapter" : (!Sys.btOn ? "Off" : (Sys.btDevice !== "" ? "Connected to " + Sys.btDevice : (Sys.btScanning ? "Scanning…" : "On")))
        IconButton { visible: Sys.btOn; code: Theme.ic.refresh; tooltip: "Scan"; color: Sys.btScanning ? Theme.purple : Theme.muted; onClicked: Sys.rescanBt() }
        Toggle { visible: Sys.btAvailable; checked: Sys.btOn; accent: Theme.purple; accessibleName: "Bluetooth"; onToggled: Sys.toggleBt() }
    }
    Divider {}
    Text { visible: Sys.btMsg !== ""; Layout.fillWidth: true; Layout.leftMargin: 4; text: Sys.btMsg; color: Sys.btMsg === "Pairing…" ? Theme.muted : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap }
    Text { visible: Sys.btInfo !== ""; Layout.fillWidth: true; Layout.leftMargin: 4; text: Sys.btInfo; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap }

    SectionLabel { visible: Sys.btOn && bt.paired.length > 0; title: "Paired devices"; subtitle: "Right-click a device to forget it" }
    Repeater {
        model: Sys.btOn ? bt.paired : []
        delegate: ActionRow {
            required property var modelData
            code: modelData.connected ? Theme.ic.btConnected : Theme.ic.bt
            accent: modelData.connected ? Theme.purple : Theme.muted
            title: modelData.name
            subtitle: modelData.busy ? "Working…" : (modelData.connected ? "Connected" + (modelData.battery >= 0 ? " · " + modelData.battery + "% battery" : "") : "Not connected")
            trailing: modelData.connected ? "Disconnect" : "Connect"
            highlighted: modelData.connected
            onClicked: modelData.connected ? Sys.btDisconnect(modelData.mac) : Sys.btConnect(modelData.mac)
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.RightButton; onClicked: Sys.btRemove(modelData.mac) }
        }
    }
    SectionLabel { visible: Sys.btOn && bt.found.length > 0; title: "Available devices" }
    Repeater {
        model: Sys.btOn ? bt.found.slice(0, 12) : []
        delegate: ActionRow {
            required property var modelData
            code: Theme.ic.bt
            accent: Theme.dim
            title: modelData.name
            subtitle: "Available"
            trailing: "Pair"
            onClicked: Sys.btPair(modelData.mac)
        }
    }
    Empty { visible: !Sys.btAvailable; code: Theme.ic.btOff; title: "No Bluetooth adapter"; hint: "bluetooth.service may be stopped" }
    Empty { visible: Sys.btAvailable && !Sys.btOn; code: Theme.ic.btOff; title: "Bluetooth is off"; hint: "Turn it on to see devices" }
    Empty {
        visible: Sys.btOn && Sys.btList.length === 0
        code: Theme.ic.bt
        title: Sys.btScanning ? "Scanning…" : "No devices found"
        hint: Sys.btScanning ? "Looking for nearby devices" : "Put a device in pairing mode and refresh"
    }
    ActionRow {
        code: Theme.ic.cog
        accent: Theme.muted
        title: "Bluetooth manager"
        subtitle: Sys.btManager ? "Scan, pair and connect devices" : "blueman not installed · opens bluetoothctl"
        onClicked: { Sys.close(); if (Sys.btManager) Sys.run(["blueman-manager"]); else Sys.run(["kitty", "-e", "bluetoothctl"]) }
    }
}
