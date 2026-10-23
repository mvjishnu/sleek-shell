import QtQuick
import QtQuick.Layouts
import qs.services

// Built-in palettes as swatches. The selected one is ringed; names show on hover.
GridLayout {
    id: grid
    columns: 6
    rowSpacing: 6
    columnSpacing: 6
    property bool showNames: false

    Repeater {
        model: Theme.palettes
        delegate: Item {
            id: cell
            required property var modelData
            readonly property bool selected: Theme.paletteId === modelData.id && Theme.activeTheme === ""
            Layout.fillWidth: true
            Layout.preferredHeight: grid.showNames ? 58 : 40
            activeFocusOnTab: true
            Accessible.role: Accessible.RadioButton
            Accessible.name: modelData.name + " palette"
            Accessible.checked: selected
            Keys.onPressed: e => { if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { Theme.setPalette(modelData.id); e.accepted = true } }

            Rectangle {
                id: ring
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 2 }
                width: 36; height: 36; radius: 18
                color: "transparent"
                border.width: cell.selected || cell.activeFocus || ma.containsMouse ? 2 : 0
                border.color: cell.activeFocus ? Theme.text : (cell.selected ? Theme.accent : Theme.border)
                Rectangle {
                    anchors.centerIn: parent
                    width: 28; height: 28; radius: 14
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.rgb(cell.modelData.accent) }
                        GradientStop { position: 1; color: Theme.rgb(cell.modelData.tint) }
                    }
                    scale: ma.pressed ? 0.88 : (ma.containsMouse ? 1.06 : 1)
                    Behavior on scale { enabled: Theme.animations; NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }
                    Glyph { anchors.centerIn: parent; code: cell.selected ? Theme.ic.check : 0; color: "#ffffff"; size: 14 }
                }
            }
            Text {
                visible: grid.showNames
                anchors { horizontalCenter: parent.horizontalCenter; top: ring.bottom; topMargin: 3 }
                text: cell.modelData.name
                color: cell.selected ? Theme.text : Theme.muted
                font.family: Theme.font; font.pixelSize: Theme.fontXs
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { cell.forceActiveFocus(); Theme.setPalette(cell.modelData.id) } }
        }
    }
}
