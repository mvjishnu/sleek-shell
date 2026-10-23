import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// A titled card on a settings page.
Rectangle {
    id: sec
    property string title: ""
    property string subtitle: ""
    default property alias content: col.data
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 32
    radius: Theme.radius
    color: Theme.surface
    border.width: Theme.strokeWidth
    border.color: Theme.stroke
    antialiasing: true

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 12
        ColumnLayout {
            visible: sec.title !== ""
            Layout.fillWidth: true
            spacing: 2
            Text { text: sec.title; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
            Text { visible: sec.subtitle !== ""; text: sec.subtitle; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        }
    }
}
