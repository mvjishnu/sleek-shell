import QtQuick
import qs.services

// Pill switch.
Item {
    id: t
    property bool checked: false
    property color accent: Theme.accent
    property string accessibleName: "Toggle"
    property bool enabled: true
    signal toggled()
    implicitWidth: 42
    implicitHeight: 24
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: accessibleName
    Accessible.checked: checked
    Keys.onPressed: event => {
        if (!t.enabled) return
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { toggled(); event.accepted = true }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        antialiasing: true
        color: t.checked ? t.accent : Theme.track
        border.width: t.activeFocus ? 2 : 0
        border.color: Theme.text
        Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
        Rectangle {
            width: 18; height: 18; radius: 9
            antialiasing: true
            y: 3
            x: t.checked ? parent.width - width - 3 : 3
            color: t.checked ? (Theme.luminance(t.accent) > 0.55 ? "#14122a" : "#ffffff") : Theme.text
            Behavior on x { enabled: Theme.animations; NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        }
    }
    MouseArea { anchors.fill: parent; enabled: t.enabled; cursorShape: Qt.PointingHandCursor; onClicked: { t.forceActiveFocus(); t.toggled() } }
}
