import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Now-playing card (MPRIS). Hidden when nothing is playing or paused.
Rectangle {
    id: m
    readonly property var p: Sys.player
    visible: !!p
    Layout.fillWidth: true
    implicitHeight: 64
    radius: Theme.controlRadius
    color: Theme.surface
    RowLayout {
        anchors { fill: parent; margins: 8 }
        spacing: 10
        Rectangle {
            implicitWidth: 48; implicitHeight: 48; radius: Theme.smallRadius
            color: Qt.alpha(Theme.accent, 0.18)
            clip: true
            Glyph { anchors.centerIn: parent; code: Theme.ic.music; color: Theme.accent; visible: art.status !== Image.Ready }
            Image { id: art; anchors.fill: parent; source: m.p && m.p.trackArtUrl ? m.p.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 96; sourceSize.height: 96 }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { text: m.p ? (m.p.trackTitle || m.p.identity || "Unknown") : ""; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontLg; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { text: m.p ? (m.p.trackArtist || m.p.identity || "") : ""; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; elide: Text.ElideRight; Layout.fillWidth: true }
        }
        IconButton { code: Theme.ic.prev; enabled: !!m.p && m.p.canGoPrevious; tooltip: "Previous"; onClicked: Sys.mediaPrev() }
        IconButton { code: Sys.mediaPlaying ? Theme.ic.pause : Theme.ic.play; color: Theme.accent; enabled: !!m.p && m.p.canTogglePlaying; tooltip: "Play / pause"; onClicked: Sys.mediaPlayPause() }
        IconButton { code: Theme.ic.next; enabled: !!m.p && m.p.canGoNext; tooltip: "Next"; onClicked: Sys.mediaNext() }
    }
}
