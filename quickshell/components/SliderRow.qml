import QtQuick
import QtQuick.Layouts
import qs.services

// Icon button + track + percentage. value is 0..100.
RowLayout {
    id: s
    property int code: 0
    property color accent: Theme.cyan
    property real value: 0
    property real from: 0
    property real display: value
    property real keyboardStep: 5
    property string valueText: ""
    property string accessibleName: "Setting"
    property bool showValue: true
    signal moved(real v)
    signal iconClicked()
    spacing: 8
    Layout.fillWidth: true

    onValueChanged: if (!ma.pressed) display = value

    IconButton { code: s.code; color: s.accent; hoverColor: s.accent; onClicked: s.iconClicked() }

    Item {
        id: track
        Layout.fillWidth: true
        implicitHeight: 28
        activeFocusOnTab: true
        Accessible.role: Accessible.Slider
        Accessible.name: s.accessibleName + ": " + (s.valueText !== "" ? s.valueText : Math.round(s.display) + "%")

        function nudge(delta) {
            var next = Math.max(s.from, Math.min(100, s.display + delta))
            s.display = next
            s.moved(next)
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) nudge(-s.keyboardStep)
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) nudge(s.keyboardStep)
            else if (event.key === Qt.Key_Home) { s.display = s.from; s.moved(s.display) }
            else if (event.key === Qt.Key_End) { s.display = 100; s.moved(s.display) }
            else return
            event.accepted = true
        }

        Rectangle {
            id: rail
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 8; radius: 4
            antialiasing: true
            color: Theme.track
            Rectangle {
                width: Math.max(8, rail.width * (s.display - s.from) / (100 - s.from))
                height: parent.height; radius: 4
                antialiasing: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha(s.accent, 0.55) }
                    GradientStop { position: 1; color: s.accent }
                }
            }
        }
        Rectangle {   // soft halo
            width: 30; height: 30; radius: 15
            antialiasing: true
            anchors.verticalCenter: parent.verticalCenter
            x: (rail.width - 16) * (s.display - s.from) / (100 - s.from) - 7
            color: Qt.alpha(s.accent, 0.28)
            opacity: ma.pressed || ma.containsMouse ? 1 : 0
            Behavior on opacity { enabled: Theme.animations; NumberAnimation { duration: Theme.durFast } }
        }
        Rectangle {
            width: 16; height: 16; radius: 8
            antialiasing: true
            anchors.verticalCenter: parent.verticalCenter
            x: (rail.width - width) * (s.display - s.from) / (100 - s.from)
            color: Theme.text
            border.width: track.activeFocus ? 2 : 0
            border.color: s.accent
            scale: ma.pressed ? 1.15 : 1
            Behavior on scale { enabled: Theme.animations; NumberAnimation { duration: Theme.durFast } }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            function set(mx) {
                var f = Math.max(0, Math.min(1, mx / width))
                s.display = s.from + f * (100 - s.from)
                s.moved(s.display)
            }
            onPressed: mouse => { track.forceActiveFocus(); set(mouse.x) }
            onPositionChanged: mouse => { if (pressed) set(mouse.x) }
        }
    }

    Text {
        visible: s.showValue
        text: s.valueText !== "" ? s.valueText : Math.round(s.display) + "%"
        color: Theme.muted
        font.family: Theme.font; font.pixelSize: 12
        Layout.preferredWidth: 36
        horizontalAlignment: Text.AlignRight
    }
}
