import QtQuick
import qs.services

// Text button. selected = primary/active, danger = destructive.
Rectangle {
    id: b
    property string label: ""
    property int code: 0
    property bool selected: false
    property bool danger: false
    property bool enabled: true
    signal clicked()
    implicitWidth: row.implicitWidth + 22
    implicitHeight: 30
    radius: Theme.smallRadius
    antialiasing: true
    opacity: enabled ? 1 : 0.45
    color: selected ? Qt.alpha(Theme.accent, ma.containsMouse ? 0.40 : 0.30)
         : (danger && ma.containsMouse ? Qt.alpha(Theme.red, 0.18) : (ma.containsMouse ? Theme.surfaceHi : Theme.surface))
    border.width: activeFocus ? 2 : Theme.strokeWidth
    border.color: activeFocus ? Theme.text : (selected ? Qt.alpha(Theme.accent, 0.8) : Theme.stroke)
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: label
    Keys.onPressed: e => { if (b.enabled && (e.key === Qt.Key_Return || e.key === Qt.Key_Space)) { b.clicked(); e.accepted = true } }
    Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
    scale: ma.pressed ? 0.96 : 1
    Behavior on scale { enabled: Theme.animations; NumberAnimation { duration: Theme.durFast } }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Glyph { visible: b.code > 0; code: b.code; size: 14; implicitWidth: 16; implicitHeight: 16; anchors.verticalCenter: parent.verticalCenter
                color: b.danger ? Theme.red : (b.selected ? Theme.text : Theme.muted) }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: b.label
            color: b.danger ? Theme.red : Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontMd
            font.weight: b.selected ? Font.DemiBold : Font.Normal
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: b.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
