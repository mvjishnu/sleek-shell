import QtQuick
import qs.services

// Visual layers of a bar pill, shared by every bar element:
//   soft contact shadow · glass gradient · top sheen (liquid-glass highlight) · hairline stroke ·
//   state overlay (hover / press / active) that fills the whole pill.
// Plain Rectangles only (no blur, no layers), so it costs next to nothing to draw.
Item {
    id: ps
    property bool hovered: false
    property bool pressed: false
    property bool active: false
    property color tone: Theme.accent
    property bool flat: false            // overlay only (used inside another pill)
    readonly property real r: Theme.pill(height)

    Rectangle {                          // contact shadow, 1 px below
        visible: !ps.flat && Theme.shadows
        anchors { fill: parent; topMargin: 1; bottomMargin: -1 }
        radius: ps.r
        color: Theme.light ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(0, 0, 0, 0.28)
    }
    Rectangle {                          // glass body
        visible: !ps.flat
        anchors.fill: parent
        radius: ps.r
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.glassBarTop }
            GradientStop { position: 1; color: Theme.glassBarBottom }
        }
    }
    Rectangle {                          // sheen on the upper half
        visible: !ps.flat && Theme.styleMode === "glass"
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
        height: parent.height * 0.55
        radius: ps.r - 1
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.pillSheen }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {                          // state overlay
        anchors.fill: parent
        radius: ps.r
        antialiasing: true
        color: ps.active ? Qt.alpha(ps.tone, ps.pressed ? 0.30 : (ps.hovered ? 0.26 : 0.20))
             : (ps.pressed ? Theme.pillPress : (ps.hovered ? Theme.pillHover : "transparent"))
        Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
    }
    Rectangle {                          // hairline stroke (accent-tinted while active)
        visible: !ps.flat || ps.active
        anchors.fill: parent
        radius: ps.r
        antialiasing: true
        color: "transparent"
        border.width: Theme.shellBorders || ps.active ? 1 : 0
        border.color: ps.active ? Qt.alpha(ps.tone, 0.45) : Theme.pillStroke
        Behavior on border.color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
    }
}
