import QtQuick
import qs.services

// One icon, drawn centred in a fixed box.
//
// Centring never uses the font's line box / advance width, which is what made icons look a little
// right/low inside their pills:
//   * Material Symbols are drawn optically centred in their em square (measured: every bar glyph's
//     rendered ink centre is within 0.5 px of the em centre), so the em square is centred.
//   * Nerd Font MDI glyphs are not (~13 px of ink on a 9.6 px advance, sitting low), so their ink
//     bounds (TextMetrics.tightBoundingRect) are centred instead.
// The baseline is snapped to physical pixels, so this holds at any scale (1.0, 1.25, …) and size.
//
//   name: Material Symbols icon from Theme.sym (modern, consistent stroke) — falls back to MDI
//   code: legacy Material Design (Nerd Font) code point
Item {
    id: g
    property int code: 0
    property string name: ""
    property color color: Theme.text
    property int size: Theme.iconPanel
    property real fill: 0          // Material Symbols FILL axis (0 outline … 1 filled)
    property int weight: 500       // Material Symbols wght axis
    property bool animateFill: true

    readonly property var entry: name !== "" ? Theme.sym[name] : undefined
    readonly property bool useSymbols: !!entry && Theme.hasSymbols
    readonly property string glyphText: useSymbols ? String.fromCodePoint(entry[0])
        : (entry ? Theme.glyph(entry[1]) : Theme.glyph(code))
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    function snap(v) { return Math.round(v * dpr) / dpr }

    readonly property real inkWidth: tm.tightBoundingRect.width
    implicitWidth: Theme.iconBox
    implicitHeight: Theme.iconBox
    visible: glyphText !== ""

    property real fillNow: fill
    Behavior on fillNow { enabled: g.animateFill && Theme.animations; NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic } }

    Text {
        id: label
        text: g.glyphText
        color: g.color
        font.family: g.useSymbols ? Theme.symbolFont : Theme.iconFont
        // MDI fallback glyphs render optically larger than Material Symbols at the same size
        font.pixelSize: g.useSymbols ? g.size : Math.round(g.size * 0.9)
        font.variableAxes: g.useSymbols ? ({ "FILL": g.fillNow, "wght": g.weight, "opsz": Math.max(20, Math.min(48, g.size)), "GRAD": 0 }) : ({})
        x: g.useSymbols ? g.snap((g.width - tm.advanceWidth) / 2)
                        : g.snap((g.width - tm.tightBoundingRect.width) / 2 - tm.tightBoundingRect.x)
        // snap the BASELINE to the physical pixel grid (Qt rounds the scaled baseline itself;
        // snapping y instead would double-round and drift by a pixel at fractional scales)
        y: (g.useSymbols ? g.snap((g.height + font.pixelSize) / 2)
                         : g.snap((g.height - tm.tightBoundingRect.height) / 2 - tm.tightBoundingRect.y)) - baselineOffset
        Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
    }
    TextMetrics { id: tm; font: label.font; text: g.glyphText }
    FontMetrics { id: fm; font: label.font }
}
