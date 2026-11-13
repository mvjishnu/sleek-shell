import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Services.UPower
import qs.services
import qs.components
import qs.modules.settings
import "../../lock/idle.js" as Idle

SettingsPage {
    id: lp
    title: "Lock screen"
    subtitle: "Choose the lock screen wallpaper, style and idle behavior."
    readonly property string home: Quickshell.env("HOME")
    readonly property string acTag: Settings.idleBatterySeparate ? " (plugged in)" : ""
    property string folder: home + "/Pictures"
    readonly property string effectiveLockStyle: Settings.lockStyleMode === "inherit" ? Theme.styleMode : Settings.lockStyleMode
    FolderListModel {
        id: lockImages
        folder: "file://" + Settings.wallpaperPath
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    SettingsSection {
        title: "Lock screen appearance"
        subtitle: "Choose a wallpaper and surface style. The clock style is set below."
        SectionLabel { title: "Surface style"; subtitle: "Match the desktop or choose Solid / Glass just for the lock screen." }
        Segment {
            model: [
                { id: "inherit", label: "Match desktop", code: Theme.ic.monitor },
                { id: "solid", label: "Solid", code: Theme.ic.palette },
                { id: "glass", label: "Glass", code: Theme.ic.drop }
            ]
            current: Settings.lockStyleMode
            onPicked: optionId => Settings.set("lockStyleMode", optionId)
        }
        LabeledSlider {
            label: "Wallpaper blur"
            enabled: lp.effectiveLockStyle === "glass"
            valueText: enabled ? Settings.lockBlur + " px" : "Off in Solid"
            code: Theme.ic.drop
            accent: Theme.purple
            from: 0
            value: Settings.lockBlur * 100 / 48
            onMoved: v => Settings.set("lockBlur", Math.round(v * 48 / 100))
            onReset: Settings.set("lockBlur", Settings.defaults.lockBlur)
        }
        LabeledSlider {
            label: "Wallpaper shade"
            valueText: Settings.lockShade + "%"
            code: Theme.ic.sun
            accent: Theme.accent
            from: 0
            value: Settings.lockShade * 100 / 80
            onMoved: v => Settings.set("lockShade", Math.round(v * 80 / 100))
            onReset: Settings.set("lockShade", Settings.defaults.lockShade)
        }
        Divider {}
        SectionLabel { title: "Lock screen wallpaper"; subtitle: "Saved separately from the desktop wallpaper. Empty selection uses a plain background." }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            UiField {
                id: lockWallpaperField
                Layout.fillWidth: true
                code: Theme.ic.image
                text: Settings.lockWallpaper
                placeholder: "~/Pictures/wallpaper.jpg"
                onAccepted: Settings.set("lockWallpaper", text.trim())
            }
            UiBtn { label: "Clear selection"; code: Theme.ic.close; onClicked: { Settings.set("lockWallpaper", ""); lockWallpaperField.text = "" } }
            UiBtn { label: "Apply path"; selected: true; onClicked: Settings.set("lockWallpaper", lockWallpaperField.text.trim()) }
        }
        GridView {
            id: lockWallpaperGrid
            Layout.fillWidth: true
            Layout.preferredHeight: lockImages.count === 0 ? 0 : Math.min(Math.ceil(lockImages.count / Math.max(1, Math.floor(width / cellWidth))) * cellHeight, 2 * cellHeight + 4)
            cellWidth: 148; cellHeight: 94
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: lockImages
            delegate: Item {
                id: lockWallpaperCell
                required property string filePath
                width: lockWallpaperGrid.cellWidth; height: lockWallpaperGrid.cellHeight
                readonly property bool selected: Settings.lockWallpaper === filePath
                Rectangle {
                    anchors { fill: parent; margins: 4 }
                    radius: Theme.controlRadius
                    clip: true
                    color: Theme.surfaceHi
                    border.width: lockWallpaperCell.selected ? 2 : 0
                    border.color: Theme.accent
                    Image {
                        anchors.fill: parent
                        source: "file://" + lockWallpaperCell.filePath
                        sourceSize: Qt.size(280, 180)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.set("lockWallpaper", lockWallpaperCell.filePath)
                }
            }
        }
        Text {
            visible: lockImages.status === FolderListModel.Ready && lockImages.count === 0
            text: "No images found in " + Settings.wallpaperDir
            color: Theme.dim
            font.family: Theme.font; font.pixelSize: Theme.fontMd
        }
    }

    SettingsSection {
        title: "Lock screen clock"
        subtitle: "The lock screen is intentionally minimal: a large clock, the date and nothing else."
        SettingRow {
            title: "Clock style"
            subtitle: "Nothing-style dot matrix, large digital, split cards or a minimal analog dial. The lock screen is static — no entry or tick animations."
            Segment {
                width: 330
                model: [
                    { id: "dots", label: "Dots" },
                    { id: "digital", label: "Digital" },
                    { id: "flip", label: "Flip" },
                    { id: "analog", label: "Analog" }
                ]
                current: Settings.lockClockStyle
                onPicked: optionId => Settings.set("lockClockStyle", optionId)
            }
        }
        SettingRow {
            title: "Clock format"
            subtitle: Settings.lockClockFormat === "follow" ? "Follow Bar & widgets, or choose a lock screen format." : "The 12-hour format includes AM/PM. This does not change the desktop clock."
            Segment {
                width: 310
                model: [{ id: "12h", label: "12-hour · AM/PM" }, { id: "24h", label: "24-hour" }, { id: "follow", label: "Follow bar" }]
                current: Settings.lockClockFormat
                onPicked: optionId => Settings.set("lockClockFormat", optionId)
            }
        }
    }

    SettingsSection {
        title: "Idle & sleep"
        subtitle: "Timers start after your last keyboard, mouse or touchpad input. Changes apply immediately."
        SectionLabel { title: "When plugged in"; subtitle: "These timeouts apply on AC power, and whenever separate battery timeouts are disabled." }
        SectionLabel { title: "Lock the screen after" + lp.acTag; subtitle: "Uses the same Sleek Shell lock screen as Super+L" }
        Segment {
            model: Settings.idleLockChoices.map(function (m) { return { id: String(m), label: Idle.minLabel(m), code: 0 } })
            current: String(Settings.idleLockMin)
            onPicked: optionId => Settings.set("idleLockMin", Number(optionId))
        }
        SectionLabel { title: "Turn the display off after" + lp.acTag; subtitle: "Any input turns it back on. Works whether or not the screen is locked." }
        Segment {
            model: Settings.idleScreenChoices.map(function (m) { return { id: String(m), label: Idle.minLabel(m), code: 0 } })
            current: String(Settings.idleScreenOffMin)
            onPicked: optionId => Settings.set("idleScreenOffMin", Number(optionId))
        }
        SectionLabel { title: "Sleep (suspend) after" + lp.acTag; subtitle: "Locks first, then suspends the computer. Set to Never to keep it awake." }
        Segment {
            model: Settings.idleSuspendChoices.map(function (m) { return { id: String(m), label: Idle.minLabel(m), code: 0 } })
            current: String(Settings.idleSuspendMin)
            onPicked: optionId => Settings.set("idleSuspendMin", Number(optionId))
        }
        SectionLabel { title: "Dim the screen before"; subtitle: "Fades the screen before it locks or turns off, so you can move the mouse in time" }
        Segment {
            model: Settings.idleDimChoices.map(function (m) { return { id: String(m), label: Idle.secLabel(m), code: 0 } })
            current: String(Settings.idleDimSec)
            onPicked: optionId => Settings.set("idleDimSec", Number(optionId))
        }
        Text {
            Layout.fillWidth: true
            visible: Settings.idleLockMin === 0 && (Settings.idleScreenOffMin > 0 || Settings.idleSuspendMin > 0)
            text: "Automatic locking is off: the display can turn off or the laptop can suspend while still unlocked."
            wrapMode: Text.WordWrap
            color: Theme.yellow
            font.family: Theme.font; font.pixelSize: Theme.fontMd
        }
        Divider {}
        SettingRow {
            visible: Sys.hasBattery || Settings.idleBatterySeparate
            title: "Use separate timeouts on battery"
            subtitle: UPower.onBattery ? "Running on battery now" : "Plugged in now: the timeouts above apply"
            Toggle { checked: Settings.idleBatterySeparate; accessibleName: "Different timeouts on battery"; onToggled: Settings.set("idleBatterySeparate", !Settings.idleBatterySeparate) }
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: Settings.idleBatterySeparate
            spacing: 8
            SectionLabel { title: "When on battery"; subtitle: "These values apply while unplugged." }
            SectionLabel { title: "On battery: lock after" }
            Segment {
                model: Settings.idleLockChoices.map(function (m) { return { id: String(m), label: Idle.minLabel(m), code: 0 } })
                current: String(Settings.idleBatteryLockMin)
                onPicked: optionId => Settings.set("idleBatteryLockMin", Number(optionId))
            }
            SectionLabel { title: "On battery: turn the display off after" }
            Segment {
                model: Settings.idleScreenChoices.map(function (m) { return { id: String(m), label: Idle.minLabel(m), code: 0 } })
                current: String(Settings.idleBatteryScreenOffMin)
                onPicked: optionId => Settings.set("idleBatteryScreenOffMin", Number(optionId))
            }
            SectionLabel { title: "On battery: sleep (suspend) after" }
            Segment {
                model: Settings.idleSuspendChoices.map(function (m) { return { id: String(m), label: Idle.minLabel(m), code: 0 } })
                current: String(Settings.idleBatterySuspendMin)
                onPicked: optionId => Settings.set("idleBatterySuspendMin", Number(optionId))
            }
        }
        Divider {}
        SettingRow {
            title: "Respect apps that keep the screen awake"
            subtitle: "Video players, browsers playing video and presentations can pause the idle timers"
            Toggle { checked: Settings.idleRespectInhibitors; accessibleName: "Respect idle inhibitors"; onToggled: Settings.set("idleRespectInhibitors", !Settings.idleRespectInhibitors) }
        }
        SettingRow {
            title: "Lock before sleep"
            subtitle: "Always locks securely before suspend, including when the laptop lid is closed."
        }
    }
}
