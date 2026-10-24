import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.services
import qs.components
import qs.modules.settings
import "../../lock/idle.js" as Idle

SettingsPage {
    id: lp
    title: "Lock screen"
    subtitle: "Your profile picture and what the lock screen shows. The picture is copied into ~/.config/sleek-shell/; the original file is never changed."
    readonly property string home: Quickshell.env("HOME")
    readonly property string acTag: Settings.idleBatterySeparate ? " (plugged in)" : ""
    property string folder: home + "/Pictures"
    property string realName: Quickshell.env("USER") || ""
    FileView {
        path: "/etc/passwd"; blockLoading: true; printErrors: false
        onLoaded: {
            var u = Quickshell.env("USER"), l = text().split("\n")
            for (var i = 0; i < l.length; ++i) { var f = l[i].split(":"); if (f[0] === u && f[4]) { lp.realName = f[4].split(",")[0]; break } }
        }
    }
    Process { id: preview; command: ["quickshell", "ipc", "call", "lock", "test"] }

    SettingsSection {
        title: "Profile picture"
        subtitle: "Shown in a circle on the lock screen (and on the login screen after `sudo ~/.local/share/sleek-shell/greeter/install.sh --sync`)."
        RowLayout {
            Layout.fillWidth: true
            spacing: 18
            Avatar { id: big; size: 96; name: lp.realName; showPicture: true }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Text { text: lp.realName; color: Theme.text; font.family: Theme.font; font.pixelSize: 18; font.weight: Font.DemiBold }
                Text { text: big.hasPicture ? "Custom picture" : "No picture: your initial is shown"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontMd }
                RowLayout {
                    spacing: 8
                    UiBtn { label: "Remove picture"; code: Theme.ic.trash; danger: true; enabled: big.hasPicture; onClicked: Settings.clearAvatar() }
                    UiBtn { label: "Preview lock screen"; code: Theme.ic.lock; onClicked: { Ui.closeSettings(); previewDelay.restart() } }
                }
            }
        }
        Timer { id: previewDelay; interval: 350; onTriggered: preview.running = true }
        Text {
            visible: Settings.avatarMsg !== ""
            Layout.fillWidth: true
            text: Settings.avatarMsg
            color: Theme.red
            font.family: Theme.font; font.pixelSize: Theme.fontMd
        }
        Divider {}
        SectionLabel { title: "Choose a picture"; subtitle: "Click an image to use it. Square images look best; others are cropped to the centre." }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [{ l: "Pictures", p: lp.home + "/Pictures" }, { l: "Wallpapers", p: lp.home + "/Pictures/Wallpapers" },
                        { l: "Screenshots", p: lp.home + "/Pictures/Screenshots" }, { l: "Downloads", p: lp.home + "/Downloads" }]
                delegate: UiBtn { required property var modelData; label: modelData.l; selected: lp.folder === modelData.p; onClicked: lp.folder = modelData.p }
            }
        }
        FolderListModel {
            id: imgs
            folder: "file://" + lp.folder
            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
            showDirs: false
            sortField: FolderListModel.Time
            // ~/Pictures often only holds sub-folders: fall through to the first folder that has images
            property bool autoPicked: false
            onStatusChanged: if (status === FolderListModel.Ready && count === 0 && !autoPicked) {
                autoPicked = true
                var order = [lp.home + "/Pictures/Wallpapers", lp.home + "/Pictures/Screenshots", lp.home + "/Downloads"]
                lp.folder = order[0]
            }
        }
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.preferredHeight: imgs.count === 0 ? 0 : Math.min(Math.ceil(imgs.count / Math.max(1, Math.floor(width / cellWidth))) * cellHeight, 2 * cellHeight + 4)
            cellWidth: 92; cellHeight: 92
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: imgs
            delegate: Item {
                id: cell
                required property string filePath
                width: grid.cellWidth; height: grid.cellHeight
                Rectangle {
                    anchors { fill: parent; margins: 5 }
                    radius: Theme.controlRadius
                    color: Theme.surfaceHi
                    clip: true
                    border.width: cma.containsMouse ? 2 : 0
                    border.color: Theme.accent
                    Image {
                        anchors { fill: parent; margins: parent.border.width }
                        source: "file://" + cell.filePath
                        sourceSize: Qt.size(160, 160)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    scale: cma.pressed ? 0.95 : 1
                    Behavior on scale { enabled: Theme.animations; NumberAnimation { duration: Theme.durFast } }
                }
                MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Settings.setAvatar(cell.filePath) }
            }
        }
        Text {
            visible: imgs.status === FolderListModel.Ready && imgs.count === 0
            text: "No images in " + lp.folder.replace(lp.home, "~")
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontMd
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            UiField { id: pathField; Layout.fillWidth: true; code: Theme.ic.image; placeholder: "…or type a path, e.g. ~/Pictures/me.jpg"; onAccepted: Settings.setAvatar(text) }
            UiBtn { label: "Use this file"; selected: true; enabled: pathField.text.trim() !== ""; onClicked: Settings.setAvatar(pathField.text) }
        }
    }

    SettingsSection {
        title: "What the lock screen shows"
        subtitle: "Your windows are never visible on the lock screen; these control the extras."
        SettingRow {
            title: "Profile picture"
            subtitle: "Off shows your initial instead"
            Toggle { checked: Settings.lockAvatar; accessibleName: "Show profile picture"; onToggled: Settings.set("lockAvatar", !Settings.lockAvatar) }
        }
        SettingRow {
            title: "Notification count"
            subtitle: "“Locked · 3 notifications” (never the contents)"
            Toggle { checked: Settings.lockShowNotifications; accessibleName: "Show notification count"; onToggled: Settings.set("lockShowNotifications", !Settings.lockShowNotifications) }
        }
        SettingRow {
            title: "Media controls"
            subtitle: "Now playing with previous / play-pause / next"
            Toggle { checked: Settings.lockShowMedia; accessibleName: "Show media controls"; onToggled: Settings.set("lockShowMedia", !Settings.lockShowMedia) }
        }
        SettingRow {
            title: "Clock format"
            subtitle: "Follows Settings › Bar & widgets (" + (Settings.clock24h ? "24-hour" : "12-hour") + ")"
            UiBtn { label: "Change"; onClicked: Ui.settingsPage = "bar" }
        }
    }

    SettingsSection {
        title: "Idle & sleep"
        subtitle: "Timers start after your last keyboard, mouse or touchpad input. Changes apply immediately."
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
        SectionLabel { title: "Suspend after" + lp.acTag; subtitle: "The screen is locked first. Never suspends desktops by default, so downloads and long tasks are not interrupted." }
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
            title: "Different timeouts on battery"
            subtitle: UPower.onBattery ? "Running on battery now" : "Plugged in now: the timeouts above apply"
            Toggle { checked: Settings.idleBatterySeparate; accessibleName: "Different timeouts on battery"; onToggled: Settings.set("idleBatterySeparate", !Settings.idleBatterySeparate) }
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: Settings.idleBatterySeparate
            spacing: 8
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
            SectionLabel { title: "On battery: suspend after" }
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
            subtitle: "Locks before suspend from any source (lid, power button, menu), so the desktop is never shown on wake"
            Toggle { checked: Settings.lockBeforeSleep; accessibleName: "Lock before sleep"; onToggled: Settings.set("lockBeforeSleep", !Settings.lockBeforeSleep) }
        }
    }
}
