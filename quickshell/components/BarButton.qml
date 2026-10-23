import QtQuick
import qs.services

// A bar pill with an icon and optional labels. Used directly in the bar (draws its own pill) or
// inside an Island with `flat: true` (only the state overlay).
//
// Geometry is explicit, so contents are centred exactly: an icon-only pill gives the icon the full
// pill as its box (Glyph centres the ink in it); icon + label pills use optical padding (icons carry
// side-bearing inside their box, text does not).
Item {
    id: b
    property int code: 0                 // legacy MDI code point
    property string icon: ""             // Theme.sym name (Material Symbols)
    property string iconTrack: ""        // optional full-extent glyph drawn faintly under `icon` (signal levels)
    property color iconColor: Theme.text
    property string label: ""
    property string label2: ""
    property bool active: false
    property bool flat: false
    property int badge: 0
    property int iconSize: Theme.barIcon
    property string tooltip: ""
    readonly property bool hovered: ma.containsMouse
    signal clicked()
    signal rightClicked()
    signal wheel(int delta)

    readonly property bool hasIcon: icon !== "" || code > 0
    readonly property bool iconOnly: hasIcon && label === "" && label2 === ""
    // Icon + label: padding is measured to the icon's INK (not its box), so both sides look equal.
    readonly property int padR: 12
    readonly property int gap: 6
    readonly property real inkW: Math.max(1, glyph.inkWidth)
    readonly property real glyphX: padR - (Theme.barIconBox - inkW) / 2
    readonly property real labelX: hasIcon ? Math.round(padR + inkW + gap) : padR

    implicitHeight: Theme.islandHeight
    implicitWidth: iconOnly ? Theme.islandHeight + 8
        : labelX + l1.implicitWidth + (label2 !== "" ? gap + l2.implicitWidth : 0) + padR

    Accessible.role: Accessible.Button
    Accessible.name: tooltip !== "" ? tooltip : label

    PillSurface {
        anchors.fill: parent
        flat: b.flat
        hovered: ma.containsMouse
        pressed: ma.pressed
        active: b.active
        tone: b.iconColor
    }

    Item {
        id: content
        anchors.fill: parent
        transformOrigin: Item.Center
        scale: ma.pressed ? 0.92 : 1
        Behavior on scale { enabled: Theme.animations; NumberAnimation { duration: Theme.dur(170); easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

        Glyph {                          // faint full shape: keeps level icons' footprint constant and centred
            visible: b.iconTrack !== "" && b.iconTrack !== b.icon
            x: glyph.x; width: glyph.width; height: parent.height
            name: b.iconTrack
            color: Qt.alpha(b.iconColor, 0.28)
            size: b.iconSize
            animateFill: false
        }
        Glyph {
            id: glyph
            visible: b.hasIcon
            x: b.iconOnly ? 0 : b.glyphX
            width: b.iconOnly ? parent.width : Theme.barIconBox
            height: parent.height
            name: b.icon
            code: b.code
            color: b.iconColor
            size: b.iconSize
            fill: b.active ? 1 : 0
        }
        BarLabel {
            id: l1
            visible: b.label !== ""
            x: b.labelX
            height: parent.height
            text: b.label
            color: Theme.text
        }
        BarLabel {
            id: l2
            visible: b.label2 !== ""
            x: l1.x + l1.implicitWidth + b.gap
            height: parent.height
            text: b.label2
            color: Theme.muted
            weight: Font.Medium
            size: Theme.barLabelSize - 1
            baselineOverride: l1.textBaseline          // one baseline for time + date
        }
    }

    Rectangle {                                     // badge, ringed so it reads on any background
        visible: b.badge > 0
        width: 8; height: 8; radius: 4
        x: b.width - width - (b.iconOnly ? 6 : 5); y: 4
        color: Theme.pink
        border.width: 1.5
        border.color: Theme.glassBarTop
        scale: visible ? 1 : 0
        Behavior on scale { enabled: Theme.animations; NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutBack } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => mouse.button === Qt.RightButton ? b.rightClicked() : b.clicked()
        onWheel: wheel => b.wheel(wheel.angleDelta.y)
    }
}
