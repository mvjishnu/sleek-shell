import QtQuick
import qs.services

// Bar text, optically centred: the cap / digit height (not the line box with its descender space)
// is centred in the pill. Labels in one pill can share a baseline via `baselineOverride`.
Item {
    id: bl
    property string text: ""
    property color color: Theme.text
    property int size: Theme.barLabelSize
    property int weight: Font.DemiBold
    property real baselineOverride: -1
    readonly property real capHeight: cap.tightBoundingRect.height
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property real textBaseline: Math.round((height + capHeight) / 2 * dpr) / dpr   // on the physical grid
    implicitWidth: Math.ceil(t.implicitWidth)
    implicitHeight: Theme.islandHeight
    Text {
        id: t
        text: bl.text
        color: bl.color
        font.family: Theme.font
        font.pixelSize: bl.size
        font.weight: bl.weight
        font.features: { "tnum": 1 }
        y: (bl.baselineOverride >= 0 ? bl.baselineOverride : bl.textBaseline) - baselineOffset
        Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
    }
    TextMetrics { id: cap; font: t.font; text: "0H" }
    FontMetrics { id: fm; font: t.font }
}
