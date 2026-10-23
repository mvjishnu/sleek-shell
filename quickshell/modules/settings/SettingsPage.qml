import QtQuick
import QtQuick.Layouts
import qs.services

// Scrollable page body: title + sections.
Flickable {
    id: page
    property string title: ""
    property string subtitle: ""
    default property alias content: col.data
    contentWidth: width
    contentHeight: col.implicitHeight + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ColumnLayout {
        id: col
        x: 24; y: 22
        width: page.width - 48
        spacing: 14
        ColumnLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            spacing: 2
            Text { text: page.title; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontHero; font.weight: Font.Bold }
            Text { visible: page.subtitle !== ""; text: page.subtitle; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontMd; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        }
    }
    Rectangle {
        visible: page.contentHeight > page.height
        parent: page
        width: 3; radius: 2
        height: Math.max(24, page.height * page.height / page.contentHeight)
        x: page.width - 6
        y: (page.height - height) * page.contentY / Math.max(1, page.contentHeight - page.height)
        color: Qt.alpha(Theme.accent, 0.6)
    }
}
