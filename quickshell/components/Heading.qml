import QtQuick
import QtQuick.Layouts
import qs.services

// Dropdown title row. Put IconButtons / Toggles inside as children.
RowLayout {
    id: h
    property string title: ""
    property string subtitle: ""
    default property alias trailing: right.data
    Layout.fillWidth: true
    spacing: 8

    ColumnLayout {
        spacing: 0
        Layout.fillWidth: true
        Text { text: h.title; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontXl; font.weight: Font.Bold }
        Text {
            visible: h.subtitle !== ""
            text: h.subtitle; color: Theme.muted
            font.family: Theme.font; font.pixelSize: Theme.fontMd
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
    Row { id: right; spacing: 4; Layout.alignment: Qt.AlignVCenter }
}
