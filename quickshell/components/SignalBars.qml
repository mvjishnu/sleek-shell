import QtQuick
import qs.services

// Tiny 4-bar signal-strength indicator, drawn from shapes (no icon font needed).
Item {
    id: s
    property int level: 0          // 0-100
    property color color: Theme.text
    property int bars: 4
    implicitWidth: 16
    implicitHeight: 12

    readonly property int on: level <= 0 ? 0
        : Math.max(1, Math.min(bars, Math.ceil(level / (100 / bars))))

    Row {
        anchors { right: parent.right; bottom: parent.bottom }
        spacing: 2
        Repeater {
            model: s.bars
            delegate: Rectangle {
                required property int index
                width: 2.5
                height: 3 + index * (s.height - 3) / (s.bars - 1)
                radius: 1.25
                antialiasing: true
                anchors.bottom: parent.bottom
                color: index < s.on ? s.color : Qt.alpha(s.color, 0.22)
            }
        }
    }
}
