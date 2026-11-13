import QtQuick
import QtQuick.Layouts
import qs.services

// Shared five-step glass control for full Appearance settings and the bar popup.
ColumnLayout {
    id: control
    Layout.fillWidth: true
    spacing: 3

    readonly property var presets: [
        { label: "Clear", glass: 0.00, blurSize: 0, blurPasses: 1 },
        { label: "Mostly clear", glass: 0.08, blurSize: 4, blurPasses: 1 },
        { label: "Balanced", glass: 0.16, blurSize: 8, blurPasses: 1 },
        { label: "Frosted", glass: 0.28, blurSize: 15, blurPasses: 2 },
        { label: "Deep frost", glass: 0.40, blurSize: 18, blurPasses: 2 }
    ]

    function selectedIndex() {
        var best = 0, distance = Infinity
        for (var i = 0; i < presets.length; ++i) {
            var d = Math.abs(Theme.glassOpacity - presets[i].glass)
            if (d < distance) { distance = d; best = i }
        }
        return best
    }
    function applyLevel(index) {
        var preset = presets[Math.max(0, Math.min(presets.length - 1, index))]
        Theme.setMany({ glass: preset.glass, blurSize: preset.blurSize, blurPasses: preset.blurPasses, blurBrightness: 100 })
    }

    SliderRow {
        code: Theme.ic.drop
        accent: Theme.cyan
        accessibleName: "Glass finish"
        valueWidth: 96
        valueText: control.presets[control.selectedIndex()].label
        from: 0
        stepSize: 25
        keyboardStep: 25
        value: control.selectedIndex() * 25
        onMoved: v => control.applyLevel(Math.round(v / 25))
    }
}
