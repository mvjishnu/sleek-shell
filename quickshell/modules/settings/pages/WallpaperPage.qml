import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.services
import qs.components
import qs.modules.settings

SettingsPage {
    id: wp
    title: "Wallpaper"
    subtitle: "Powered by awww through wallpaper-next.sh, the same script SUPER+W uses, so the choice is remembered."
    property string current: ""

    function apply(args) {
        Sys.run(["env", "WALLPAPER_DIR=" + Settings.wallpaperPath, "AWWW_TRANSITION=" + Settings.wallpaperTransition,
                 Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-next.sh"].concat(args))
        reread.restart()
    }
    FileView {
        id: last
        path: Quickshell.env("HOME") + "/.local/state/awww-rice/last-wallpaper"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: wp.current = text().trim()
    }
    Timer { id: reread; interval: 400; onTriggered: last.reload() }

    FolderListModel {
        id: folder
        folder: "file://" + Settings.wallpaperPath
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    SettingsSection {
        title: "Pictures"
        subtitle: folder.status === FolderListModel.Ready ? folder.count + " images in " + Settings.wallpaperDir : "Loading " + Settings.wallpaperDir + "…"
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(Math.ceil(count / Math.max(1, Math.floor(width / cellWidth))) * cellHeight, 420)
            cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 190)))
            cellHeight: cellWidth * 0.62
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: folder
            delegate: Item {
                id: cell
                required property string filePath
                required property string fileName
                readonly property bool selected: wp.current === filePath
                width: grid.cellWidth; height: grid.cellHeight
                Rectangle {
                    anchors { fill: parent; margins: 5 }
                    radius: Theme.controlRadius
                    color: Theme.surfaceHi
                    border.width: cell.selected ? 3 : (cma.containsMouse ? 2 : 0)
                    border.color: cell.selected ? Theme.accent : Theme.border
                    clip: true
                    Image {
                        anchors { fill: parent; margins: parent.border.width }
                        source: "file://" + cell.filePath
                        sourceSize.width: 320; sourceSize.height: 200
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { enabled: Theme.animations; NumberAnimation { duration: Theme.durBase } }
                    }
                    Rectangle {
                        visible: cell.selected
                        anchors { right: parent.right; top: parent.top; margins: 8 }
                        width: 24; height: 24; radius: 12; color: Theme.accent
                        Glyph { anchors.centerIn: parent; code: Theme.ic.check; color: Theme.onAccent; size: 14 }
                    }
                    scale: cma.pressed ? 0.97 : 1
                    Behavior on scale { enabled: Theme.animations; NumberAnimation { duration: Theme.durFast } }
                }
                MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wp.apply(["set", cell.filePath]) }
            }
        }
        Empty { visible: folder.status === FolderListModel.Ready && folder.count === 0; code: Theme.ic.wallpaper; title: "No images found"; hint: "Put .png / .jpg / .webp files in " + Settings.wallpaperDir }
        RowLayout {
            spacing: 8
            UiBtn { label: "Previous"; code: Theme.ic.left; onClicked: wp.apply(["prev"]) }
            UiBtn { label: "Next"; code: Theme.ic.right; onClicked: wp.apply(["next"]) }
            UiBtn { label: "Random"; code: Theme.ic.shuffle; onClicked: wp.apply(["random"]) }
            UiBtn { label: "Open folder"; code: Theme.ic.folder; onClicked: { Ui.closeSettings(); Sys.run(["xdg-open", Settings.wallpaperPath]) } }
        }
    }
    SettingsSection {
        title: "Behaviour"
        SectionLabel { title: "Transition" }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: Settings.transitions
                delegate: UiBtn { required property string modelData; label: modelData; selected: Settings.wallpaperTransition === modelData; onClicked: Settings.set("wallpaperTransition", modelData) }
            }
        }
        SectionLabel { title: "Folder" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            UiField { id: dirField; Layout.fillWidth: true; code: Theme.ic.folder; text: Settings.wallpaperDir; onAccepted: Settings.set("wallpaperDir", text) }
            UiBtn { label: "Use folder"; onClicked: Settings.set("wallpaperDir", dirField.text) }
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "SUPER+W / SUPER+SHIFT+W always use ~/Pictures/Wallpapers unless WALLPAPER_DIR is set; this page passes your folder and transition explicitly."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
    }
}
