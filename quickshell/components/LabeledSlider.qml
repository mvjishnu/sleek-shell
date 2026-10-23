import QtQuick
import QtQuick.Layouts
import qs.services

// "Label ........ value" over a slider. Clicking the icon resets to default.
ColumnLayout {
    id: ls
    property string label: ""
    property string valueText: ""
    property int code: 0
    property color accent: Theme.accent
    property real from: 0
    property real value: 0
    property bool enabled: true
    signal moved(real v)
    signal reset()
    Layout.fillWidth: true
    spacing: 2
    opacity: enabled ? 1 : 0.45

    RowLayout {
        Layout.fillWidth: true
        Text { text: ls.label; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; Layout.fillWidth: true }
        Text { text: ls.valueText; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; font.weight: Font.DemiBold }
    }
    SliderRow {
        enabled: ls.enabled
        accessibleName: ls.label
        code: ls.code
        accent: ls.accent
        from: ls.from
        value: ls.value
        showValue: false
        onMoved: v => { if (ls.enabled) ls.moved(v) }
        onIconClicked: if (ls.enabled) ls.reset()
    }
}
