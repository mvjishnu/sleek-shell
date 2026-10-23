import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Appearance quick panel (bar palette pill / SUPER+SHIFT+A). The full editor is Settings > Appearance;
// both drive the same Theme store, so they always show the same state.
ColumnLayout {
    id: ap
    property bool compact: true
    spacing: Theme.settingsGap
    Layout.fillWidth: true

    Heading {
        title: "Appearance"
        subtitle: (Theme.activeTheme !== "" ? Theme.activeTheme : Theme.palette.name) + " · " + (Theme.light ? "Light" : "Dark") + " · " + (Theme.styleMode === "glass" ? "Liquid glass" : "Solid")
        IconButton { code: Theme.ic.cog; tooltip: "All appearance settings"; visible: ap.compact; onClicked: { Sys.close(); Ui.openSettings("appearance") } }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Segment {
            Layout.preferredWidth: 1
            model: [{ id: "dark", label: "Dark", code: Theme.ic.moon }, { id: "light", label: "Light", code: Theme.ic.sun }]
            current: Theme.mode
            onPicked: optionId => Theme.set("mode", optionId)
        }
        Segment {
            Layout.preferredWidth: 1
            model: [{ id: "solid", label: "Solid", code: Theme.ic.palette }, { id: "glass", label: "Glass", code: Theme.ic.drop }]
            current: Theme.styleMode
            onPicked: optionId => Theme.set("styleMode", optionId)
        }
    }

    SectionLabel { title: "Palette" }
    PaletteGrid { Layout.fillWidth: true; columns: 6 }

    SectionLabel { title: "Accent" }
    AccentRow { Layout.fillWidth: true }

    Divider {}
    LabeledSlider {
        label: "Glass opacity"
        valueText: Theme.glassOpacity < 0.3 ? "Clear" : (Theme.glassOpacity < 0.55 ? "Translucent" : (Theme.glassOpacity < 0.8 ? "Soft" : "Opaque"))
        code: Theme.ic.snow; accent: Theme.cyan
        from: 15; value: Theme.glassOpacity * 100
        onMoved: v => Theme.set("glass", v / 100)
        onReset: Theme.set("glass", Theme.defaults.glass)
    }
    LabeledSlider {
        label: "Blur"
        enabled: Theme.styleMode === "glass"
        valueText: Theme.styleMode === "glass" ? Theme.blurSize + " px" : "Off (solid)"
        code: Theme.ic.drop; accent: Theme.purple
        from: 100 / 24; value: Theme.blurSize * 100 / 24
        onMoved: v => Theme.set("blurSize", v * 24 / 100)
        onReset: Theme.set("blurSize", Theme.defaults.blurSize)
    }
    SettingRow {
        title: "Window borders"
        subtitle: Theme.borderWidth === 0 ? "Off" : (Theme.colorfulBorders ? "Accent gradient · " : "Accent · ") + Theme.borderWidth + " px"
        Toggle { checked: Theme.borderWidth > 0; accessibleName: "Window borders"; onToggled: Theme.set("borderWidth", Theme.borderWidth > 0 ? 0 : 2) }
    }
    SettingRow {
        title: "Panel outlines & separators"
        subtitle: Theme.shellBorders ? "Shown" : "Hidden everywhere in the shell"
        Toggle { checked: Theme.shellBorders; accessibleName: "Panel outlines"; onToggled: Theme.set("shellBorders", !Theme.shellBorders) }
    }
    Text {
        Layout.fillWidth: true
        text: Theme.compositorStatus
        visible: Theme.compositorStatus.indexOf("Hyprland:") === 0
        color: Theme.red
        font.family: Theme.font; font.pixelSize: Theme.fontXs
        wrapMode: Text.WordWrap
    }
    UiBtn { visible: ap.compact; Layout.fillWidth: true; code: Theme.ic.cog; label: "More appearance settings"; onClicked: { Sys.close(); Ui.openSettings("appearance") } }
}
