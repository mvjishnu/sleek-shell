import QtQuick
import qs.services

// "SUPER + SHIFT + W" drawn as key caps.
Row {
    id: kc
    property string keys: ""
    property bool big: false
    spacing: 4
    clip: true
    readonly property var names: ({ SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift", left: "←", right: "→", up: "↑", down: "↓",
        "mouse:272": "Left drag", "mouse:273": "Right drag", Tab: "Tab", Return: "Enter", space: "Space", Print: "PrtSc",
        XF86AudioRaiseVolume: "Vol +", XF86AudioLowerVolume: "Vol −", XF86AudioMute: "Mute", XF86AudioMicMute: "Mic mute",
        XF86MonBrightnessUp: "Bright +", XF86MonBrightnessDown: "Bright −", XF86AudioNext: "Next", XF86AudioPrev: "Prev",
        XF86AudioPlay: "Play", XF86AudioPause: "Pause", Escape: "Esc" })
    Repeater {
        model: String(kc.keys).split("+").map(function (x) { return x.trim() }).filter(function (x) { return x !== "" })
        delegate: Rectangle {
            required property string modelData
            height: kc.big ? 30 : 22
            width: Math.max(height, t.implicitWidth + (kc.big ? 18 : 12))
            radius: Theme.smallRadius * (kc.big ? 1 : 0.75)
            color: Theme.surfaceHi
            border.width: 1
            border.color: Theme.light ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.10)
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 } height: 2; radius: 1; color: Qt.alpha(Theme.ink, 0.10) }
            Text {
                id: t
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: kc.names[parent.modelData] || (parent.modelData.length === 1 ? parent.modelData.toUpperCase() : parent.modelData)
                color: Theme.text
                font.family: Theme.font; font.pixelSize: kc.big ? Theme.fontLg : Theme.fontSm; font.weight: Font.DemiBold
            }
        }
    }
}
