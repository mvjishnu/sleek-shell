import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

ColumnLayout {
    Layout.fillWidth: true
    spacing: Theme.dropdownGap
    Heading { title: "Brightness"; subtitle: Sys.hasBacklight ? Sys.backlightDevice : "Display backlight unavailable" }
    SliderRow {
        visible: Sys.hasBacklight
        code: Theme.ic.sun
        accent: Theme.yellow
        accessibleName: "Screen brightness"
        from: 1
        value: Sys.brightness
        onMoved: v => Sys.setBrightness(v)
    }
    Text {
        visible: !Sys.hasBacklight
        text: "No backlight device was found."
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: Theme.fontSm
    }
}
