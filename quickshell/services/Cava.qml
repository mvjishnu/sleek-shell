pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// One low-rate CAVA process feeds every monitor and avoids duplicate readers.
// sleep_timer in cava.conf parks the process on silence, so an idle desktop stays cheap.
Singleton {
    id: cava
    readonly property string home: Quickshell.env("HOME")
    property string spectrum: ""
    property bool active: false
    readonly property string glyphs: " ▁▂▃▄▅▆▇█"
    readonly property int barCount: 18
    property var target: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    property var level:  [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

    function accept(line) {
        var raw = line.trim().split(";").filter(function (x) { return x !== "" })
        var values = raw.map(function (x) { var n = Number(x); return isNaN(n) ? 0 : Math.max(0, Math.min(1, n / 100)) })
        if (values.length === 0) return
        if (values.length !== cava.barCount) {
            var compact = []
            for (var i = 0; i < cava.barCount; ++i) {
                var first = Math.floor(i * values.length / cava.barCount)
                var last = Math.max(first + 1, Math.floor((i + 1) * values.length / cava.barCount))
                var peak = 0
                for (var j = first; j < last && j < values.length; ++j) peak = Math.max(peak, values[j])
                compact.push(peak)
            }
            values = compact
        }
        target = values
        active = Math.max.apply(null, values) > 0.012
    }

    Timer {
        // 30 fps is plenty for 18 tiny bars and halves the QML work while audio plays.
        interval: 32; repeat: true
        running: active || level.some(function (v) { return v > 0.012 })
        onTriggered: {
            var next = [], changed = false
            for (var i = 0; i < cava.barCount; ++i) {
                var d = target[i] - level[i]
                var v = level[i] + d * (d > 0 ? 0.30 : 0.16)
                if (Math.abs(d) < 0.002) v = target[i]
                next.push(v); if (Math.abs(v - level[i]) > 0.001) changed = true
            }
            if (changed) {
                level = next
                spectrum = next.map(function (n) { return cava.glyphs.charAt(Math.max(0, Math.min(8, Math.round(n * 8)))) }).join("")
            }
        }
    }

    Process {
        id: process
        command: ["cava", "-p", cava.home + "/.config/quickshell/cava.conf"]
        running: true
        stdout: SplitParser { onRead: line => cava.accept(line) }
        onExited: code => {
            cava.active = false
            restartTimer.start()
        }
    }
    Timer { id: restartTimer; interval: 3000; onTriggered: process.running = true }
}
