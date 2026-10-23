import QtQuick
import qs.services

// A glass pill that holds several things in a row (workspace dots, the centre island).
// Single buttons use BarButton, which draws the same pill itself.
Item {
    id: isl
    default property alias content: row.data
    property int inset: 0
    property alias spacing: row.spacing
    property bool hovered: false
    property bool active: false
    property color tone: Theme.accent
    height: Theme.islandHeight
    width: row.implicitWidth + inset * 2
    Behavior on width { enabled: Theme.animations; NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic } }

    PillSurface { anchors.fill: parent; hovered: isl.hovered; active: isl.active; tone: isl.tone }

    Row {
        id: row
        x: isl.inset
        height: parent.height
        spacing: 0
    }
}
