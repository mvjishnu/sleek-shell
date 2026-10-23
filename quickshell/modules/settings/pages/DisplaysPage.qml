import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.components
import qs.modules.settings

SettingsPage {
    title: "Displays"
    subtitle: "Resolution, refresh rate, scale, rotation and position. Changes are tried live with a 15-second automatic revert."

    SettingsSection {
        title: "Connected monitors"
        Repeater {
            model: Hyprland.monitors
            delegate: SettingRow {
                required property var modelData
                readonly property var o: modelData.lastIpcObject || ({})
                code: Theme.ic.monitor
                title: modelData.name + (modelData.focused ? "  ·  focused" : "")
                subtitle: (o.description || "") + "\n" + (o.width || modelData.width) + "×" + (o.height || modelData.height) + " @ " + Math.round((o.refreshRate || 0) * 10) / 10 + " Hz · scale " + (o.scale || modelData.scale) + " · position " + (o.x || 0) + "," + (o.y || 0)
            }
        }
        RowLayout {
            spacing: 8
            UiBtn { label: "Open display settings (SUPER+SHIFT+D)"; code: Theme.ic.monitor; selected: true; onClicked: { Ui.closeSettings(); ipc.running = true } }
            UiBtn { label: "nwg-displays"; code: Theme.ic.cog; onClicked: { Ui.closeSettings(); Sys.run(["nwg-displays"]) } }
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Saved overrides go to ~/.config/hypr/monitors_custom.lua; the nwg-displays files are never modified."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
    }
    Item { Process { id: ipc; command: ["quickshell", "ipc", "call", "monitors", "toggle"] } }
}
