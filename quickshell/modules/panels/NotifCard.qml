import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components

// One notification: icon, app, time, summary, body, action buttons. Used by the history and the pop-ups.
Rectangle {
    id: c
    required property var item
    property bool popup: false
    signal closeRequested()
    readonly property bool critical: item.urgency === 2
    readonly property color tone: critical ? Theme.pink : Theme.cyan

    implicitHeight: col.implicitHeight + 22
    radius: popup ? Theme.radius : Theme.controlRadius
    antialiasing: true
    color: popup ? "transparent" : Theme.surface

    RowLayout {
        id: row
        anchors { fill: parent; margins: 11 }
        spacing: 10
        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 34; implicitHeight: 34; radius: Theme.pill(34)
            color: Qt.alpha(c.tone, 0.18)
            Glyph { anchors.centerIn: parent; visible: icon.status !== Image.Ready; code: c.critical ? Theme.ic.bellRing : Theme.ic.bell; color: c.tone }
            IconImage {
                id: icon
                anchors.centerIn: parent
                implicitSize: 22
                visible: status === Image.Ready
                source: c.item.appIcon || ""
                asynchronous: true
            }
        }
        ColumnLayout {
            id: col
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                Text { text: c.item.appName; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: Theme.timeAgo(c.item.time); color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm }
            }
            Text { text: c.item.summary; visible: text !== ""; color: Theme.text; font.family: Theme.font; font.pixelSize: c.popup ? 14 : Theme.fontLg; font.weight: Font.DemiBold
                   wrapMode: Text.Wrap; Layout.fillWidth: true; maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.PlainText }
            Text { text: c.item.body; visible: text !== ""; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontMd
                   wrapMode: Text.Wrap; Layout.fillWidth: true; maximumLineCount: 4; elide: Text.ElideRight; textFormat: Text.PlainText }
            Flow {
                visible: c.item.actions && c.item.actions.length > 0
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                Repeater {
                    model: c.item.actions || []
                    delegate: UiBtn {
                        required property var modelData
                        label: modelData.text || modelData.id
                        onClicked: Notifs.invoke(c.item.id, modelData.id)
                    }
                }
            }
        }
        IconButton { Layout.alignment: Qt.AlignTop; boxSize: 26; code: Theme.ic.close; tooltip: "Dismiss"; onClicked: c.closeRequested() }
    }
}
