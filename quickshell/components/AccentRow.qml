import QtQuick
import QtQuick.Layouts
import qs.services

// Palette accent + preset swatches + custom hex field + reset.
RowLayout {
    id: row
    spacing: 6
    readonly property var swatches: [Theme.palette.accent].concat(Theme.accentSwatches)

    Repeater {
        model: row.swatches
        delegate: Item {
            id: sw
            required property var modelData
            required property int index
            readonly property string hexv: "#" + Theme.hex(modelData)
            readonly property bool selected: index === 0 ? Theme.accentOverride === "" : Theme.accentOverride.toLowerCase() === hexv
            implicitWidth: 26; implicitHeight: 26
            activeFocusOnTab: true
            Accessible.role: Accessible.RadioButton
            Accessible.name: index === 0 ? "Palette accent" : "Accent " + hexv
            Keys.onPressed: e => { if (e.key === Qt.Key_Return || e.key === Qt.Key_Space) { pick(); e.accepted = true } }
            function pick() { Theme.set("accent", index === 0 ? "" : hexv) }
            Rectangle {
                anchors.fill: parent; radius: 13
                color: "transparent"
                border.width: sw.selected || sw.activeFocus ? 2 : 0
                border.color: sw.activeFocus ? Theme.text : Theme.accent
                Rectangle { anchors.centerIn: parent; width: 18; height: 18; radius: 9; color: Theme.rgb(sw.modelData)
                    scale: sma.containsMouse ? 1.12 : 1
                    Behavior on scale { enabled: Theme.animations; NumberAnimation { duration: Theme.durFast } } }
            }
            MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { sw.forceActiveFocus(); sw.pick() } }
        }
    }
    Item { Layout.fillWidth: true }
    UiField {
        id: hexField
        implicitWidth: 92
        placeholder: "#hex"
        text: Theme.accentHex
        error: text !== "" && !Theme.validHex(text)
        onAccepted: if (Theme.validHex(text)) Theme.set("accent", text)
        Connections { target: Theme; function onAccentHexChanged() { if (!hexField.input.activeFocus) hexField.text = Theme.accentHex } }
        input.onEditingFinished: { if (Theme.validHex(text)) Theme.set("accent", text); else text = Theme.accentHex }
    }
}
