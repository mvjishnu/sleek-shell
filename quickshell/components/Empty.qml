import QtQuick
import QtQuick.Layouts
import qs.services

// Empty-state block.
ColumnLayout {
    property int code: 0
    property string title: ""
    property string hint: ""
    Layout.fillWidth: true
    Layout.topMargin: 14
    Layout.bottomMargin: 14
    spacing: 6
    Glyph { code: parent.code; size: 30; color: Theme.dim; Layout.alignment: Qt.AlignHCenter; implicitWidth: 34; implicitHeight: 34 }
    Text { text: parent.title; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignHCenter }
    Text { visible: parent.hint !== ""; text: parent.hint; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter }
}
