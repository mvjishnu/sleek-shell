import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components
import qs.modules.settings

SettingsPage {
    title: "Bar & widgets"
    subtitle: "Choose what the top bar shows and in which order. Changes apply to every monitor immediately."

    SettingsSection {
        title: "Layout"
        SettingRow {
            title: "Density"
            subtitle: "Pill height of the bar"
            Segment {
                width: 240
                model: [{ id: "compact", label: "Compact", code: 0 }, { id: "comfortable", label: "Comfortable", code: 0 }]
                current: Settings.barDensity
                onPicked: optionId => Settings.set("barDensity", optionId)
            }
        }
        SettingRow {
            title: "Icon colours"
            subtitle: "Colourful keeps each widget's tone; monochrome uses the text colour (alerts stay coloured)"
            Segment {
                width: 240
                model: [{ id: "color", label: "Colourful", code: 0 }, { id: "mono", label: "Monochrome", code: 0 }]
                current: Settings.barIconStyle
                onPicked: optionId => Settings.set("barIconStyle", optionId)
            }
        }
        SettingRow {
            title: "Workspace indicator"
            Segment {
                width: 240
                model: [{ id: "dots", label: "Dots", code: 0 }, { id: "numbers", label: "Numbers", code: 0 }]
                current: Settings.workspaceStyle
                onPicked: optionId => Settings.set("workspaceStyle", optionId)
            }
        }
    }

    SettingsSection {
        title: "Clock"
        SettingRow { title: "24-hour time"; Toggle { checked: Settings.clock24h; accessibleName: "24-hour time"; onToggled: Settings.set("clock24h", !Settings.clock24h) } }
        SettingRow { title: "Show seconds"; subtitle: "Updates the bar every second instead of every minute"; Toggle { checked: Settings.clockSeconds; accessibleName: "Show seconds"; onToggled: Settings.set("clockSeconds", !Settings.clockSeconds) } }
        SettingRow { title: "Show date"; Toggle { checked: Settings.clockDate; accessibleName: "Show date"; onToggled: Settings.set("clockDate", !Settings.clockDate) } }
    }

    SettingsSection {
        title: "Centre island"
        SettingRow { title: "Volume & brightness OSD"; subtitle: "The clock island briefly turns into a level meter when you press the keys"; Toggle { checked: Settings.osd; accessibleName: "OSD"; onToggled: Settings.set("osd", !Settings.osd) } }
        SettingRow { title: "Now playing"; subtitle: "Show the playing track next to the clock (click: play/pause, right-click: next)"; Toggle { checked: Settings.islandMedia; accessibleName: "Now playing"; onToggled: Settings.set("islandMedia", !Settings.islandMedia) } }
    }

    Repeater {
        model: [{ side: "left", title: "Left side", key: "leftOrder" }, { side: "right", title: "Right side", key: "rightOrder" }]
        delegate: SettingsSection {
            id: sec
            required property var modelData
            title: modelData.title
            subtitle: "Eye toggles visibility; arrows change the order."
            Repeater {
                model: Settings[sec.modelData.key]
                delegate: Rectangle {
                    id: wr
                    required property string modelData
                    required property int index
                    readonly property bool vis: Settings.shown(modelData)
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: Theme.controlRadius
                    color: wma.containsMouse ? Theme.surfaceHi : "transparent"
                    MouseArea { id: wma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 6 }
                        spacing: 8
                        Text { text: (wr.index + 1) + "."; color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontMd; Layout.preferredWidth: 18 }
                        Text { text: Settings.widgetCatalog[wr.modelData].name; color: wr.vis ? Theme.text : Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontLg; Layout.fillWidth: true
                               font.strikeout: !wr.vis }
                        IconButton { code: Theme.ic.up; tooltip: "Move earlier"; enabled: wr.index > 0; onClicked: Settings.move(wr.modelData, -1) }
                        IconButton { code: Theme.ic.down; tooltip: "Move later"; enabled: wr.index < Settings[sec.modelData.key].length - 1; onClicked: Settings.move(wr.modelData, 1) }
                        IconButton { code: wr.vis ? Theme.ic.eye : Theme.ic.eyeOff; color: wr.vis ? Theme.accent : Theme.dim; tooltip: wr.vis ? "Hide" : "Show"; onClicked: Settings.toggleHidden(wr.modelData) }
                    }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        UiBtn { label: "Reset bar & shell settings"; code: Theme.ic.restore; danger: true; onClicked: Settings.resetDefaults() }
    }
}
