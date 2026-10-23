import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components
import qs.modules.settings

SettingsPage {
    title: "Motion"
    subtitle: "One speed for everything that moves: windows, workspaces, panels, pop-ups and controls."

    SettingsSection {
        title: "Animations"
        SettingRow {
            title: "Animations"
            subtitle: Theme.animations ? "On" : "Reduced motion: windows and panels appear instantly; everything stays fully usable"
            Toggle { checked: Theme.animations; accessibleName: "Animations"; onToggled: Theme.set("animations", !Theme.animations) }
        }
        LabeledSlider {
            label: "Speed"
            enabled: Theme.animations
            valueText: Theme.animSpeed.toFixed(2) + "×" + (Math.abs(Theme.animSpeed - 1) < 0.01 ? " (default)" : (Theme.animSpeed > 1 ? " faster" : " slower"))
            code: Theme.ic.speed; accent: Theme.green
            from: 0; value: (Theme.animSpeed - 0.5) / 1.5 * 100
            onMoved: v => Theme.set("animSpeed", Math.round((0.5 + v / 100 * 1.5) * 20) / 20)
            onReset: Theme.set("animSpeed", 1)
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [{ l: "Relaxed", v: 0.75 }, { l: "Default", v: 1 }, { l: "Snappy", v: 1.35 }, { l: "Instant-ish", v: 2 }]
                delegate: UiBtn {
                    required property var modelData
                    Layout.fillWidth: true
                    label: modelData.l
                    selected: Theme.animations && Math.abs(Theme.animSpeed - modelData.v) < 0.01
                    onClicked: { Theme.set("animations", true); Theme.set("animSpeed", modelData.v) }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Hyprland: " + Theme.compositorStatus
            color: Theme.compositorStatus.indexOf("Hyprland:") === 0 ? Theme.red : Theme.dim
            font.family: Theme.font; font.pixelSize: Theme.fontSm
            wrapMode: Text.WordWrap
        }
    }

    SettingsSection {
        title: "Preview"
        subtitle: "Hover and click to feel the current speed."
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                id: demo
                property bool on: false
                Layout.fillWidth: true
                implicitHeight: 64
                radius: Theme.controlRadius
                color: Theme.surfaceHi
                Rectangle {
                    width: 48; height: 48; radius: Theme.pill(48)
                    y: 8
                    x: demo.on ? demo.width - width - 8 : 8
                    gradient: Gradient { GradientStop { position: 0; color: Theme.cyan } GradientStop { position: 1; color: Theme.accent } }
                    Behavior on x { enabled: Theme.animations; NumberAnimation { duration: Theme.dur(420); easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: demo.on = !demo.on }
            }
            Toggle { checked: demo.on; accessibleName: "Preview"; onToggled: demo.on = !demo.on }
        }
    }
}
