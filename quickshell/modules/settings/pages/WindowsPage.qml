import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components
import qs.modules.settings
import Quickshell.Io

SettingsPage {
    title: "Windows & workspaces"
    subtitle: "Compositor geometry and transparency. Applied live through Hyprland and kept across reloads."

    SettingsSection {
        title: "Geometry"
        LabeledSlider {
            label: "Window corner radius"; valueText: Theme.windowRounding + " px"
            code: Theme.ic.window; accent: Theme.accent
            from: 0; value: Theme.windowRounding / 30 * 100
            onMoved: v => Theme.set("windowRounding", v * 30 / 100)
            onReset: Theme.set("windowRounding", Theme.defaults.windowRounding)
        }
        LabeledSlider {
            label: "Gap between windows"; valueText: Theme.gapsIn + " px"
            code: Theme.ic.dashboard; accent: Theme.cyan
            from: 0; value: Theme.gapsIn / 30 * 100
            onMoved: v => Theme.set("gapsIn", v * 30 / 100)
            onReset: Theme.set("gapsIn", Theme.defaults.gapsIn)
        }
        LabeledSlider {
            label: "Gap to screen edges"; valueText: Theme.gapsOut + " px"
            code: Theme.ic.dashboard; accent: Theme.cyan
            from: 0; value: Theme.gapsOut / 60 * 100
            onMoved: v => Theme.set("gapsOut", v * 60 / 100)
            onReset: Theme.set("gapsOut", Theme.defaults.gapsOut)
        }
    }
    SettingsSection {
        title: "Transparency"
        subtitle: "Focused windows should stay more opaque than unfocused ones."
        LabeledSlider {
            label: "Focused window opacity"; valueText: Math.round(Theme.activeOpacity * 100) + "%"
            code: Theme.ic.eye; accent: Theme.purple
            from: 30; value: Theme.activeOpacity * 100
            onMoved: v => Theme.set("activeOpacity", v / 100)
            onReset: Theme.set("activeOpacity", Theme.defaults.activeOpacity)
        }
        LabeledSlider {
            label: "Unfocused window opacity"; valueText: Math.round(Theme.inactiveOpacity * 100) + "%"
            code: Theme.ic.eyeOff; accent: Theme.purple
            from: 30; value: Theme.inactiveOpacity * 100
            onMoved: v => Theme.set("inactiveOpacity", v / 100)
            onReset: Theme.set("inactiveOpacity", Theme.defaults.inactiveOpacity)
        }
        SettingRow {
            title: "Window shadows"
            subtitle: "Drop shadows under windows (costs a little GPU time)"
            Toggle { checked: Theme.windowShadows; accessibleName: "Window shadows"; onToggled: Theme.set("windowShadows", !Theme.windowShadows) }
        }
    }
    SettingsSection {
        title: "Workspaces"
        subtitle: "Every monitor keeps its own workspaces; SUPER+1…0 always means the Nth workspace of the focused monitor. A reconnected monitor gets its workspaces back."
        RowLayout {
            spacing: 8
            UiBtn { label: "Open overview (SUPER+Tab)"; code: Theme.ic.dashboard; onClicked: { Ui.closeSettings(); overviewIpc.running = true } }
            UiBtn { label: "Display settings"; code: Theme.ic.monitor; onClicked: Ui.settingsPage = "displays" }
        }
    }
    Item { Process { id: overviewIpc; command: ["quickshell", "ipc", "call", "overview", "open"] } }
}
