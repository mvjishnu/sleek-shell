import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// The centre island. Normally the clock (click: calendar + now playing). It morphs to show a
// volume / brightness OSD for a moment, and grows a now-playing chip while media plays.
// The lock screen borrows this pill (Sys.lockHideClock / Sys.clockW).
Island {
    id: isl
    required property var bar
    // The original bar style gives the clock/media island its own pill too.
    // In full-width mode, keep the shared surface reserved for the transient OSD.
    backgroundEnabled: Settings.barStyle === "pills" || osdOn
    property string osdKind: ""
    property real osdValue: 0
    property bool osdMuted: false
    property bool debugClockVisible: !osdOn
    property string debugClockText: Time.fmtTime(Time.date)
    readonly property bool osdOn: osdKind !== ""
    readonly property bool mediaOn: Settings.islandMedia && Sys.mediaPlaying && !osdOn
    // The session lock has its own full-screen surface. Keep the bar clock visible
    // underneath it so a stale lock-hidden flag cannot make the clock disappear
    // from the desktop after the lock surface has gone away.
    opacity: 1
    onWidthChanged: if (!osdOn && !mediaOn) Sys.clockW = width
    Component.onCompleted: Sys.clockW = width

    Connections {
        target: Sys
        function onOsd(kind, value, muted) {
            if (!Settings.osd || Sys.lockHideClock) return
            if (Sys.openScreen !== "" && Sys.openPopup !== "" && Sys.openScreen === isl.bar.sn) return
            if (Wm.focusedMon() !== isl.bar.sn) return
            isl.osdKind = kind; isl.osdValue = value; isl.osdMuted = muted
            osdTimer.restart()
        }
    }
    Timer { id: osdTimer; interval: 1600; onTriggered: isl.osdKind = "" }

    BarButton {
        id: clockBtn
        flat: true
        visible: !isl.osdOn
        label: Time.fmtTime(Time.date)
        label2: Settings.clockDate ? Time.fmtDate(Time.date) : ""
        active: isl.bar.isOpen("calendar")
        iconColor: Theme.text
        tooltip: "Calendar"
        onClicked: Sys.toggle("calendar", isl.bar.sn)
    }

    Item {
        id: media
        visible: isl.mediaOn
        height: Theme.islandHeight
        width: visible ? 6 + Theme.barIconBox + 4 + mtitle.width + 12 : 0
        Rectangle {
            x: 2; width: 2; height: parent.height * 0.42
            anchors.verticalCenter: parent.verticalCenter
            radius: 1
            color: Theme.barTone(Theme.accent)
        }
        Glyph { x: 6; width: Theme.barIconBox; height: parent.height; name: "music"; color: Theme.barTone(Theme.accent); size: Theme.barIcon }
        BarLabel {
            id: mtitle
            x: 6 + Theme.barIconBox + 4
            height: parent.height
            width: Math.min(implicitWidth, 200)
            clip: true
            weight: Font.Medium
            color: Theme.text
            text: Sys.player ? (Sys.player.trackTitle || Sys.player.identity || "") : ""
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => m.button === Qt.RightButton ? Sys.mediaNext() : Sys.mediaPlayPause() }
    }

    Item {
        id: osd
        visible: isl.osdOn
        height: Theme.islandHeight
        width: visible ? 196 : 0
        RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 12 }
            spacing: 8
            Glyph {
                size: Theme.barIcon; Layout.preferredWidth: Theme.barIconBox; Layout.fillHeight: true
                name: isl.osdKind === "brightness" ? "brightness" : Theme.volumeSym(isl.osdValue, isl.osdMuted)
                color: isl.osdMuted ? Theme.red : Theme.barTone(isl.osdKind === "brightness" ? Theme.yellow : Theme.cyan)
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 5; radius: 3
                color: Theme.track
                Rectangle {
                    height: parent.height; radius: 3
                    width: parent.width * Math.max(0, Math.min(1, isl.osdValue / 100))
                    color: isl.osdKind === "brightness" ? Theme.yellow : (isl.osdMuted ? Theme.muted : Theme.pink)
                    Behavior on width { enabled: Theme.animations; NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                }
            }
            BarLabel {
                text: isl.osdMuted ? "Muted" : Math.round(isl.osdValue) + "%"
                Layout.preferredWidth: 40
                Layout.fillHeight: true
                size: Theme.barLabelSize - 1
            }
        }
    }
}
