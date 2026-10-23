import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

ColumnLayout {
    Layout.fillWidth: true
    spacing: Theme.dropdownGap

    Heading {
        title: Sys.hasBattery ? Sys.batCap + "% battery" : "Display"
        subtitle: !Sys.hasBattery ? "Screen brightness" : (Sys.batState === "Charging" ? "Charging" : (Sys.batState === "Full" ? "Fully charged" : Sys.batState === "Not charging" ? "Plugged in, not charging" : "On battery")) + (Sys.batTime !== "" ? " · " + Sys.batTime : "")
    }
    Rectangle {
        visible: Sys.hasBattery
        Layout.fillWidth: true
        implicitHeight: 8; radius: 4
        color: Theme.track
        Rectangle {
            width: parent.width * Sys.batCap / 100
            height: parent.height; radius: 4
            color: Theme.batteryColor(Sys.batCap, Sys.batState)
            Behavior on width { enabled: Theme.animations; NumberAnimation { duration: Theme.durSlow } }
        }
    }
    Divider { visible: Sys.hasBacklight }
    SliderRow {
        visible: Sys.hasBacklight
        code: Theme.ic.sun
        accent: Theme.yellow
        accessibleName: "Brightness"
        from: 1
        value: Sys.brightness
        onMoved: v => Sys.setBrightness(v)
    }
    Divider { visible: Sys.profile !== "" }
    SectionLabel { visible: Sys.profile !== ""; title: "Power profile" }
    RowLayout {
        visible: Sys.profile !== ""
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: [
                { id: "power-saver", label: "Saver", code: Theme.ic.leaf, col: Theme.green, ok: true },
                { id: "balanced", label: "Balanced", code: Theme.ic.scale, col: Theme.cyan, ok: true },
                { id: "performance", label: "Boost", code: Theme.ic.rocket, col: Theme.pink, ok: Sys.hasPerformance }
            ]
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 58
                radius: Theme.controlRadius
                antialiasing: true
                opacity: modelData.ok ? 1 : 0.4
                color: Sys.profile === modelData.id ? Qt.alpha(modelData.col, 0.24) : (pMa.containsMouse ? Theme.surfaceHi : Theme.surface)
                Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    Glyph { anchors.horizontalCenter: parent.horizontalCenter; code: modelData.code; color: modelData.col }
                    Text { text: modelData.ok ? modelData.label : "Not supported"; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSm; anchors.horizontalCenter: parent.horizontalCenter }
                }
                MouseArea { id: pMa; anchors.fill: parent; enabled: modelData.ok; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Sys.setProfile(modelData.id) }
            }
        }
    }
}
