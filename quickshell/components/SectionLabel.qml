import QtQuick
import QtQuick.Layouts
import qs.services

ColumnLayout {
    id: section
    property string title: ""
    property string subtitle: ""
    Layout.fillWidth: true
    spacing: 2

    Text {
        text: section.title
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.DemiBold
        Layout.fillWidth: true
    }
    Text {
        visible: section.subtitle !== ""
        text: section.subtitle
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: 10
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
