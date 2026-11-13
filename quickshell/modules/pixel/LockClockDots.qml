import QtQuick

// Nothing-style dot-matrix time: each digit is a 5×7 grid of dots and the
// separator is two dots.  Only the lit dots are drawn, so it stays crisp at
// any size without loading a font.
Item {
    id: root
    property date now: new Date()
    property bool is24h: false
    property color ink: "#f5f6f8"

    readonly property string hh: pad(is24h ? now.getHours() : ((now.getHours() + 11) % 12 + 1))
    readonly property string mm: pad(now.getMinutes())
    function pad(n) { return (n < 10 ? "0" : "") + n }

    readonly property var masks: ({
        "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
        "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"]
    })
    readonly property var glyphs: [hh.charAt(0), hh.charAt(1), ":", mm.charAt(0), mm.charAt(1)]

    readonly property real gapUnits: 1.9                 // gap between glyphs, in dot pitches
    readonly property real pitch: d * 1.5
    readonly property real digitW: 4 * pitch + d
    readonly property real digitH: 6 * pitch + d
    readonly property real d: {
        var rows = 6 * 1.5 + 1                            // 10 dot units tall
        var cols = 4 * (4 * 1.5 + 1) + 1 + 4 * (1.5 * gapUnits)
        return Math.min(root.width / cols, root.height / rows) * 0.96
    }

    Row {
        anchors.centerIn: parent
        spacing: root.pitch * root.gapUnits
        Repeater {
            model: root.glyphs
            delegate: Item {
                id: glyph
                required property string modelData
                readonly property bool colon: modelData === ":"
                width: colon ? root.d : root.digitW
                height: root.digitH
                Repeater {
                    model: glyph.colon ? 2 : 35
                    delegate: Rectangle {
                        required property int index
                        readonly property string mask: (root.masks[glyph.modelData] || []).join("")
                        readonly property bool lit: glyph.colon || mask.charAt(index) === "1"
                        visible: lit
                        width: root.d; height: root.d
                        radius: root.d / 2
                        color: root.ink
                        x: glyph.colon ? 0 : (index % 5) * root.pitch
                        y: glyph.colon ? (index === 0 ? 2 : 4) * root.pitch : Math.floor(index / 5) * root.pitch
                    }
                }
            }
        }
    }
}
