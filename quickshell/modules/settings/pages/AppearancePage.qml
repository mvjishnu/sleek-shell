import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components
import qs.modules.settings

SettingsPage {
    id: pg
    title: "Appearance"
    subtitle: "Colours, glass, shape and type for the whole desktop: shell, window borders and themed apps (kitty, Rofi, GTK, Qt)."

    Text {
        visible: Theme.lastMessage !== ""
        Layout.fillWidth: true
        text: Theme.lastMessage
        color: Theme.accent
        font.family: Theme.font; font.pixelSize: Theme.fontMd
        wrapMode: Text.WordWrap
    }

    SettingsSection {
        title: "Theme"
        subtitle: "Light and dark switch the shell and GTK / Qt apps together. Solid turns glass and compositor blur off."
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Segment {
                Layout.preferredWidth: 1
                model: [{ id: "dark", label: "Dark", code: Theme.ic.moon }, { id: "light", label: "Light", code: Theme.ic.sun }]
                current: Theme.mode
                onPicked: optionId => Theme.set("mode", optionId)
            }
            Segment {
                Layout.preferredWidth: 1
                model: [{ id: "solid", label: "Solid", code: Theme.ic.palette }, { id: "glass", label: "Liquid glass", code: Theme.ic.drop }]
                current: Theme.styleMode
                onPicked: optionId => Theme.set("styleMode", optionId)
            }
        }
        SectionLabel { title: "Palette"; subtitle: "Tint for glass surfaces plus a matching accent." }
        PaletteGrid { Layout.fillWidth: true; columns: 6; showNames: true }
        SectionLabel { title: "Accent"; subtitle: "Pick a swatch or type any hex colour. The first swatch follows the palette." }
        AccentRow { Layout.fillWidth: true }
    }

    SettingsSection {
        title: "Your themes"
        subtitle: "Save the current look under a name, switch between saved looks, share them as files."
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            UiField { id: nameField; Layout.fillWidth: true; placeholder: "Theme name, e.g. Midnight"; code: Theme.ic.palette; onAccepted: if (Theme.saveTheme(text)) text = "" }
            UiBtn { label: "Save current"; code: Theme.ic.save; selected: true; onClicked: if (Theme.saveTheme(nameField.text)) nameField.text = "" }
        }
        Repeater {
            model: Theme.userThemes
            delegate: Rectangle {
                id: tr
                required property var modelData
                readonly property bool current: Theme.activeTheme === modelData.name
                property bool renaming: false
                readonly property var pal: Theme.findPalette(modelData.values.palette)
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Theme.controlRadius
                color: current ? Qt.alpha(Theme.accent, 0.16) : (tma.containsMouse ? Theme.surfaceHi : "transparent")
                MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Theme.applyTheme(tr.modelData.name) }
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                    spacing: 10
                    Rectangle {
                        implicitWidth: 28; implicitHeight: 28; radius: 14
                        gradient: Gradient {
                            GradientStop { position: 0; color: tr.modelData.values.accent !== "" ? tr.modelData.values.accent : Theme.rgb(tr.pal.accent) }
                            GradientStop { position: 1; color: tr.modelData.values.mode === "light" ? "#f2f2f7" : Theme.rgb(tr.pal.tint) }
                        }
                    }
                    ColumnLayout {
                        visible: !tr.renaming
                        Layout.fillWidth: true
                        spacing: 0
                        Text { text: tr.modelData.name + (tr.current ? "  ·  active" : ""); color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontLg; font.weight: tr.current ? Font.DemiBold : Font.Normal }
                        Text { text: Theme.findPalette(tr.modelData.values.palette).name + " · " + tr.modelData.values.mode + " · " + tr.modelData.values.styleMode; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm }
                    }
                    UiField {
                        id: renameField
                        visible: tr.renaming
                        Layout.fillWidth: true
                        text: tr.modelData.name
                        onAccepted: { Theme.renameTheme(tr.modelData.name, text); tr.renaming = false }
                    }
                    IconButton { code: tr.renaming ? Theme.ic.check : Theme.ic.pencil; tooltip: "Rename"; onClicked: { if (tr.renaming) Theme.renameTheme(tr.modelData.name, renameField.text); tr.renaming = !tr.renaming; if (tr.renaming) renameField.focusField() } }
                    IconButton { code: Theme.ic.save; tooltip: "Overwrite with current look"; onClicked: Theme.saveTheme(tr.modelData.name) }
                    IconButton { code: Theme.ic.exportFile; tooltip: "Export to ~/Downloads"; onClicked: Theme.exportTheme(tr.modelData.name) }
                    IconButton { code: Theme.ic.trash; tooltip: "Delete"; hoverColor: Theme.red; onClicked: Theme.deleteTheme(tr.modelData.name) }
                }
            }
        }
        Text {
            visible: Theme.userThemes.length === 0
            text: "No saved themes yet."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontMd
        }
        Divider {}
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            UiField { id: importField; Layout.fillWidth: true; code: Theme.ic.importFile; placeholder: "~/Downloads/sleek-shell-theme-….json"; onAccepted: Theme.importTheme(text) }
            UiBtn { label: "Import"; code: Theme.ic.importFile; onClicked: Theme.importTheme(importField.text) }
            UiBtn { label: "Export current"; code: Theme.ic.exportFile; onClicked: Theme.exportTheme(Theme.activeTheme !== "" ? Theme.activeTheme : "Current") }
        }
    }

    SettingsSection {
        title: "Glass and blur"
        subtitle: "Blur is rendered by Hyprland on the GPU. Fewer passes and a smaller size are cheaper."
        LabeledSlider {
            label: "Glass opacity"
            valueText: Math.round(Theme.glassOpacity * 100) + "%"
            code: Theme.ic.snow; accent: Theme.cyan
            from: 15; value: Theme.glassOpacity * 100
            onMoved: v => Theme.set("glass", v / 100)
            onReset: Theme.set("glass", Theme.defaults.glass)
        }
        LabeledSlider {
            label: "Blur size"
            enabled: Theme.styleMode === "glass"
            valueText: Theme.blurSize + " px"
            code: Theme.ic.drop; accent: Theme.purple
            from: 100 / 24; value: Theme.blurSize * 100 / 24
            onMoved: v => Theme.set("blurSize", v * 24 / 100)
            onReset: Theme.set("blurSize", Theme.defaults.blurSize)
        }
        LabeledSlider {
            label: "Blur passes"
            enabled: Theme.styleMode === "glass"
            valueText: Theme.blurPasses + (Theme.blurPasses === 1 ? " pass" : " passes")
            code: Theme.ic.drop; accent: Theme.purple
            from: 100 / 6; value: Theme.blurPasses * 100 / 6
            onMoved: v => Theme.set("blurPasses", v * 6 / 100)
            onReset: Theme.set("blurPasses", Theme.defaults.blurPasses)
        }
        LabeledSlider {
            label: "Blur brightness"
            enabled: Theme.styleMode === "glass"
            valueText: Theme.blurBrightness + "%"
            code: Theme.ic.sun; accent: Theme.yellow
            from: 0; value: (Theme.blurBrightness - 60)
            onMoved: v => Theme.set("blurBrightness", 60 + v)
            onReset: Theme.set("blurBrightness", Theme.defaults.blurBrightness)
        }
    }

    SettingsSection {
        title: "Shape and borders"
        subtitle: "Each switch does exactly what it says, everywhere: no leftover outlines, separators or shadows."
        LabeledSlider {
            label: "Corner roundness"
            valueText: Math.round(Theme.radiusScale * 100) + "%"
            code: Theme.ic.scale; accent: Theme.accent
            from: 0; value: (Theme.radiusScale - 0.4) / 1.2 * 100
            onMoved: v => Theme.set("radiusScale", 0.4 + v / 100 * 1.2)
            onReset: Theme.set("radiusScale", 1)
        }
        SettingRow {
            title: "Panel outlines & separators"
            subtitle: "Hairlines around shell cards, pills and between sections"
            Toggle { checked: Theme.shellBorders; accessibleName: "Panel outlines"; onToggled: Theme.set("shellBorders", !Theme.shellBorders) }
        }
        SettingRow {
            title: "Panel shadows"
            subtitle: "Soft shadows under dropdowns, pop-ups and settings"
            Toggle { checked: Theme.shadows; accessibleName: "Panel shadows"; onToggled: Theme.set("shadows", !Theme.shadows) }
        }
        Divider {}
        SettingRow {
            title: "Window borders"
            subtitle: Theme.compositorStatus
            Toggle { checked: Theme.borderWidth > 0; accessibleName: "Window borders"; onToggled: Theme.set("borderWidth", Theme.borderWidth > 0 ? 0 : 2) }
        }
        LabeledSlider {
            label: "Border thickness"
            enabled: Theme.borderWidth > 0
            valueText: Theme.borderWidth === 0 ? "Off" : Theme.borderWidth + " px"
            code: Theme.ic.window; accent: Theme.accent
            from: 25; value: Math.max(1, Theme.borderWidth) * 25
            onMoved: v => Theme.set("borderWidth", Math.max(1, Math.round(v / 25)))
            onReset: Theme.set("borderWidth", 2)
        }
        SettingRow {
            title: "Colourful gradient"
            subtitle: "Accent-to-palette gradient on the focused window; off uses the plain accent"
            Toggle { enabled: Theme.borderWidth > 0; checked: Theme.colorfulBorders; accessibleName: "Colourful borders"; onToggled: Theme.set("colorfulBorders", !Theme.colorfulBorders) }
        }
    }

    SettingsSection {
        title: "Typography"
        subtitle: "Font for all shell text. Icons always use JetBrainsMono Nerd Font."
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [""].concat(["Inter", "Noto Sans", "Cantarell", "Ubuntu", "Roboto", "Fira Sans", "IBM Plex Sans", "Geist", "SF Pro Display", "JetBrainsMono Nerd Font"].filter(function (f) { return Theme.fontList.indexOf(f) >= 0 }))
                delegate: UiBtn {
                    required property string modelData
                    label: modelData === "" ? "Automatic (" + (Theme.hasInter ? "Inter" : "Noto Sans") + ")" : modelData
                    selected: Theme.fontFamily === modelData
                    onClicked: Theme.set("fontFamily", modelData)
                }
            }
        }
        Text {
            visible: !Theme.hasInter
            Layout.fillWidth: true
            text: "Inter is not installed, so text uses Noto Sans. For the intended look install it with:  sudo pacman -S inter-font"
            color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap
        }
    }

    SettingsSection {
        title: "App theming"
        subtitle: Theme.themedSummary() + ". Choose which apps follow the shell theme, give one its own palette, or leave it alone."
        Segment {
            Layout.fillWidth: true
            model: [{ id: "all", label: "All supported apps", code: Theme.ic.check }, { id: "selected", label: "Only apps I pick", code: Theme.ic.palette }]
            current: Theme.appScope
            onPicked: optionId => Theme.setAppScope(optionId)
        }
        Repeater {
            model: Theme.themedApps
            delegate: ColumnLayout {
                id: appRow
                required property var modelData
                readonly property string mode: Theme.appMode(modelData.id)
                readonly property var rule: Theme.appRule(modelData.id)
                Layout.fillWidth: true
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Glyph { code: Theme.ic[appRow.modelData.icon] || 0; size: Theme.iconPanel; color: appRow.mode === "off" ? Theme.dim : Theme.accent }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: appRow.modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd }
                        Text {
                            Layout.fillWidth: true
                            text: appRow.mode === "off" ? appRow.modelData.offNote : appRow.modelData.what + "  ·  " + appRow.modelData.when
                            color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontXs; wrapMode: Text.WordWrap
                        }
                    }
                    Segment {
                        Layout.preferredWidth: 420; Layout.minimumWidth: 420; Layout.maximumWidth: 420
                        model: [{ id: "inherit", label: "Shell theme" }, { id: "custom", label: "Custom" }, { id: "off", label: "Don't theme" }]
                        current: appRow.mode
                        onPicked: optionId => Theme.setAppRule(appRow.modelData.id, { mode: optionId })
                    }
                }
                Flow {
                    visible: appRow.mode === "custom"
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.iconPanel + 10
                    spacing: 6
                    Repeater {
                        model: Theme.palettes
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: appRow.rule.palette === modelData.id
                            width: 26; height: 26; radius: 13
                            color: Theme.rgb(modelData.tint)
                            border.width: sel ? 2 : 1
                            border.color: sel ? Theme.text : Theme.border
                            Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: Theme.rgb(parent.modelData.accent) }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: Theme.setAppRule(appRow.modelData.id, { mode: "custom", palette: parent.modelData.id, accent: "" })
                            }
                            Accessible.role: Accessible.RadioButton
                            Accessible.name: appRow.modelData.name + " palette " + modelData.name
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: "Not covered: Firefox / Zen and Chromium-based apps (they follow only the light/dark preference), Flatpak apps without a GTK/Qt override, and apps with their own theme engine."
                color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontXs; wrapMode: Text.WordWrap
            }
            UiBtn { label: "Reset"; code: Theme.ic.restore; onClicked: Theme.resetApps() }
        }
    }

    SettingsSection {
        title: "Fonts, icons & cursors"
        subtitle: "Shell, app and terminal fonts, app icon themes and mouse cursors, plus hundreds more to download, now live on their own page."
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { Layout.fillWidth: true; text: "Shell: " + Theme.font + "  ·  Apps: " + Settings.appFont + "  ·  Icons: " + Settings.iconTheme + "  ·  Cursor: " + Settings.cursorTheme; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap }
            UiBtn { label: "Open"; code: Theme.ic.font; selected: true; onClicked: Ui.settingsPage = "styles" }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Item { Layout.fillWidth: true }
        UiBtn { label: "Re-apply app themes"; code: Theme.ic.refresh; onClicked: { Theme.lastExport = ""; Theme.touch(); Theme.applyHypr(); Theme.lastMessage = "Re-applied to Hyprland and " + Theme.themedSummary().toLowerCase() } }
        UiBtn { label: "Reset appearance"; code: Theme.ic.restore; danger: true; onClicked: Theme.resetDefaults() }
    }
}
