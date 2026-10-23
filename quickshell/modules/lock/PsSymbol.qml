import QtQuick
import qs.services
import qs.components
import qs.modules.lock

// One PlayStation face-button symbol, drawn as strokes so all four share the same visual weight.
// kind: 0 triangle, 1 circle, 2 cross, 3 square
Item {
    id: s
    property int kind: 0
    property bool fail: false
    readonly property var base: ["#7ee8b4", "#ff6b86", "#70b8ff", "#ff70c5"]
    readonly property color tint: fail ? "#ff6b86" : base[kind]
    width: 28
    height: 28

    onTintChanged: cv.requestPaint()
    onKindChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()

    // pop-in when a character is typed
    NumberAnimation on scale { from: 0; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 }
    NumberAnimation on rotation { from: -40; to: 0; duration: 260; easing.type: Easing.OutCubic }

    Canvas {
        id: cv
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            var c = getContext("2d")
            c.reset()
            // shapes are designed on a 28-unit grid; scale to the actual size so nothing is cut off
            var k = Math.min(width, height) / 28
            c.scale(k, k)
            c.strokeStyle = "" + s.tint
            c.lineWidth = 3.2
            c.lineCap = "round"
            c.lineJoin = "round"
            c.beginPath()
            if (s.kind === 0) { c.moveTo(14, 4.5); c.lineTo(24, 22.5); c.lineTo(4, 22.5); c.closePath() }
            else if (s.kind === 1) { c.arc(14, 14, 9.5, 0, Math.PI * 2) }
            else if (s.kind === 2) { c.moveTo(5, 5); c.lineTo(23, 23); c.moveTo(23, 5); c.lineTo(5, 23) }
            else { c.rect(5, 5, 18, 18) }
            c.stroke()
        }
    }
}
