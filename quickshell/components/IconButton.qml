import QtQuick
import qs.services

// Small square icon button used inside headers and rows.
Item {
    id: b
    property int code: 0
    property color color: Theme.muted
    property color hoverColor: Theme.text
    property int boxSize: 30
    property bool enabled: true
    property string tooltip: ""
    signal clicked()
    implicitWidth: boxSize
    implicitHeight: boxSize
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: tooltip
    Keys.onPressed: e => { if (b.enabled && (e.key === Qt.Key_Return || e.key === Qt.Key_Space)) { b.clicked(); e.accepted = true } }

    Rectangle {
        anchors.fill: parent
        radius: Theme.smallRadius
        antialiasing: true
        color: !b.enabled ? "transparent" : (ma.pressed ? Theme.surfaceHi : (ma.containsMouse || b.activeFocus ? Theme.surface : "transparent"))
        Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
    }
    Glyph { anchors.centerIn: parent; code: b.code; color: (ma.containsMouse && b.enabled) ? b.hoverColor : b.color }
    scale: ma.pressed ? 0.9 : 1
    Behavior on scale { enabled: Theme.animations; NumberAnimation { duration: Theme.durFast } }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: b.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
