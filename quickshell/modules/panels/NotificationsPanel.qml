import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

ColumnLayout {
    Layout.fillWidth: true
    spacing: Theme.dropdownGap

    Heading {
        title: "Notifications"
        subtitle: Notifs.history.length === 0 ? "Nothing new" : Notifs.history.length + (Notifs.history.length === 1 ? " notification" : " notifications")
        IconButton { code: Settings.dnd ? Theme.ic.bellOff : Theme.ic.bell; color: Settings.dnd ? Theme.pink : Theme.muted; tooltip: "Do not disturb"; onClicked: Sys.setDnd(!Settings.dnd) }
        IconButton { code: Theme.ic.trash; tooltip: "Clear all"; enabled: Notifs.history.length > 0; onClicked: Notifs.clear() }
    }
    ActionRow {
        code: Theme.ic.bellOff
        accent: Theme.pink
        title: "Do not disturb"
        subtitle: Settings.dnd ? "Pop-ups are silenced (critical still shown)" : "Pop-ups are shown"
        highlighted: Settings.dnd
        onClicked: Sys.setDnd(!Settings.dnd)
        Toggle {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            checked: Settings.dnd; accent: Theme.pink; accessibleName: "Do not disturb"
            onToggled: Sys.setDnd(!Settings.dnd)
        }
    }
    Divider {}
    ListView {
        id: nList
        visible: Notifs.history.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 420)
        clip: true
        spacing: 6
        model: Notifs.history
        boundsBehavior: Flickable.StopAtBounds
        delegate: NotifCard {
            required property var modelData
            width: nList.width
            item: modelData
            onCloseRequested: Notifs.dismiss(modelData.id)
        }
        add: Transition { enabled: Theme.animations; NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durBase } }
        displaced: Transition { enabled: Theme.animations; NumberAnimation { property: "y"; duration: Theme.durBase; easing.type: Easing.OutCubic } }
    }
    Empty { visible: Notifs.history.length === 0; code: Theme.ic.bellOff; title: "You're all caught up"; hint: "New notifications will appear here" }
}
