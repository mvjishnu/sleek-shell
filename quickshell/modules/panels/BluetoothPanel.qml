import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

ColumnLayout {
    id: bt
    Layout.fillWidth: true
    spacing: Theme.dropdownGap
    readonly property var paired: Sys.btList.filter(function (d) { return d.paired || d.connected })
    readonly property var orbitPaired: paired.filter(function (d) { return !d.connected })
    readonly property var found: Sys.btList.filter(function (d) { return !d.paired && !d.connected && d.name !== d.mac })
    readonly property var orbitDevices: orbitPaired.slice(0, 10).concat(found.slice(0, Math.max(0, 10 - orbitPaired.length)))
    readonly property var extraPaired: orbitPaired.slice(10)
    readonly property var extraFound: found.slice(Math.max(0, 10 - orbitPaired.length))

    Heading {
        title: "Bluetooth"
        subtitle: !Sys.btAvailable ? "No adapter" : (!Sys.btOn ? "Off" : (Sys.btDevice !== "" ? "Connected to " + Sys.btDevice : (Sys.btScanning ? "Scanning…" : "On")))
        IconButton { visible: Sys.btOn; code: Theme.ic.refresh; tooltip: "Scan"; color: Sys.btScanning ? Theme.purple : Theme.muted; onClicked: Sys.rescanBt() }
        Toggle { visible: Sys.btAvailable; checked: Sys.btOn; accent: Theme.purple; accessibleName: "Bluetooth"; onToggled: Sys.toggleBt() }
    }
    Divider {}
    ActionRow {
        visible: Sys.btOn && Sys.btList.some(function (d) { return d.connected })
        readonly property var connectedDevice: Sys.btList.find(function (d) { return d.connected }) || ({})
        code: Theme.ic.btConnected
        accent: Theme.purple
        title: connectedDevice.name || Sys.btDevice || "Connected device"
        subtitle: "Connected" + (connectedDevice.battery >= 0 ? " · " + connectedDevice.battery + "% battery" : "")
        trailing: "Disconnect"
        highlighted: true
        onClicked: if (connectedDevice.mac) Sys.btDisconnect(connectedDevice.mac)
    }
    OrbitChooser {
        mimeType: "application/x-sleek-bt"
        entries: Sys.btOn ? bt.orbitDevices.map(function (d) {
            return { key: d.mac, title: d.name, active: d.connected,
                     subtitle: d.connected ? "Connected" : (d.paired ? "Paired · tap to connect" : "Available · tap to pair"),
                     action: d.paired ? "connect" : "pair" }
        }) : []
        hubTitle: "Bluetooth"
        hubSubtitle: !Sys.btAvailable ? "Unavailable" : (!Sys.btOn ? "Off" : (Sys.btDevice || (Sys.btScanning ? "Scanning" : "On")))
        accent: Theme.purple
        onActivated: (entry, dropped) => {
            if (entry.active) { if (!dropped) Sys.btDisconnect(entry.key) }
            else if (entry.action === "pair") Sys.btPair(entry.key)
            else Sys.btConnect(entry.key)
        }
        onToggleRequested: Sys.toggleBt()
    }
    Text { visible: Sys.btMsg !== ""; Layout.fillWidth: true; Layout.leftMargin: 4; text: Sys.btMsg; color: Sys.btMsg === "Pairing…" ? Theme.muted : Theme.red; font.family: Theme.font; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap }
    Text { visible: Sys.btInfo !== ""; Layout.fillWidth: true; Layout.leftMargin: 4; text: Sys.btInfo; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap }

    SectionLabel { visible: Sys.btOn && bt.extraPaired.length > 0; title: "More paired devices"; subtitle: "Right-click a device to forget it" }
    Repeater {
        model: Sys.btOn ? bt.extraPaired : []
        delegate: ActionRow {
            required property var modelData
            dragData: modelData.connected ? ({}) : ({ "application/x-sleek-bt": modelData.mac, "application/x-sleek-bt-action": "connect" })
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
    SectionLabel { visible: Sys.btOn && bt.extraFound.length > 0; title: "More available devices" }
    Repeater {
        model: Sys.btOn ? bt.extraFound : []
        delegate: ActionRow {
            required property var modelData
            dragData: ({ "application/x-sleek-bt": modelData.mac, "application/x-sleek-bt-action": "pair" })
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
        onClicked: { Sys.close(); if (Sys.btManager) Sys.run(["blueman-manager"]); else Sys.run(["kitty", "--single-instance", "-e", "bluetoothctl"]) }
    }
}
