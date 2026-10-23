import QtQuick
import qs.services

Rectangle {
    id: b
    property string text: ""
    property color tone: Theme.accent
    implicitWidth: t.implicitWidth + 12
    implicitHeight: 18
    radius: 9
    color: Qt.alpha(tone, 0.18)
    Text { id: t; anchors.centerIn: parent; text: b.text; color: b.tone; font.family: Theme.font; font.pixelSize: Theme.fontXs; font.weight: Font.DemiBold }
}
