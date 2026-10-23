import QtQuick
import QtQuick.Layouts
import qs.services

// Title + optional subtitle on the left, a control (Toggle, Segment, button…) on the right.
RowLayout {
    id: sr
    property string title: ""
    property string subtitle: ""
    property int code: 0
    property color iconColor: Theme.accent
    default property alias trailing: right.data
    Layout.fillWidth: true
    spacing: 10
    Glyph { visible: sr.code > 0; code: sr.code; color: sr.iconColor; Layout.alignment: Qt.AlignVCenter }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        Text { text: sr.title; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.Medium; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        Text { visible: sr.subtitle !== ""; text: sr.subtitle; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    }
    Row { id: right; spacing: 6; Layout.alignment: Qt.AlignVCenter | Qt.AlignRight }
}
