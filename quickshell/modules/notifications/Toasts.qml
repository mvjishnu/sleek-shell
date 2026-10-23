import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.panels

// Notification pop-ups: a stack in the top-right corner of the focused monitor.
// Slide in, slide out, the rest move up. Hover pauses the timeout; critical ones stay until dismissed.
PanelWindow {
    id: win
    screen: Ui.focusedScreen()
    visible: toastModel.count > 0
    anchors { top: true; right: true }
    margins { top: Theme.barHeight + 6; right: 10 }
    implicitWidth: 380
    implicitHeight: Math.max(1, list.contentHeight)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    ListModel { id: toastModel }

    // keep the ListModel in step with Notifs.toasts so add / remove transitions run
    function sync() {
        var want = Notifs.toasts
        for (var i = toastModel.count - 1; i >= 0; --i)
            if (want.indexOf(toastModel.get(i).nid) < 0) toastModel.remove(i)
        for (var j = want.length - 1; j >= 0; --j) {
            var found = false
            for (var k = 0; k < toastModel.count; ++k) if (toastModel.get(k).nid === want[j]) { found = true; break }
            if (!found) toastModel.insert(0, { nid: want[j] })
        }
    }
    Connections { target: Notifs; function onToastsChanged() { win.sync() } }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: contentHeight
        interactive: false
        spacing: 8
        model: toastModel

        delegate: Item {
            id: d
            required property int nid
            required property int index
            readonly property var item: Notifs.find(nid)
            width: list.width
            height: card.height

            Rectangle {   // shadow
                visible: Theme.shadows
                x: card.x + 1; y: card.y + 4; width: card.width; height: card.height
                radius: card.radius; color: Theme.shadowColor
            }
            Rectangle {
                id: card
                width: parent.width
                height: body.implicitHeight
                radius: Theme.radius
                antialiasing: true
                border.width: Theme.strokeWidth
                border.color: Theme.stroke
                gradient: Gradient {
                    GradientStop { position: 0; color: d.item && d.item.urgency === 2 ? Theme.glassCritTop : Theme.glassPopTop }
                    GradientStop { position: 1; color: d.item && d.item.urgency === 2 ? Theme.glassCritBottom : Theme.glassPopBottom }
                }
                NotifCard {
                    id: body
                    width: parent.width
                    visible: !!d.item
                    item: d.item || ({ id: 0, appName: "", summary: "", body: "", time: Date.now(), urgency: 1, actions: [] })
                    popup: true
                    onCloseRequested: Notifs.hideToast(d.nid)
                }
                // progress hairline for the remaining time
                Rectangle {
                    visible: expire.running || hover.containsMouse
                    anchors { left: parent.left; bottom: parent.bottom; leftMargin: Theme.radius; bottomMargin: 3 }
                    height: 2; radius: 1
                    width: (parent.width - Theme.radius * 2) * d.remain
                    color: Qt.alpha(Theme.accent, 0.6)
                }
            }
            property real remain: 1
            readonly property int timeout: !item ? 0 : (item.urgency === 2 ? 0 : (item.timeout > 0 ? item.timeout : Settings.toastTimeout * 1000))
            NumberAnimation on remain {
                id: expire
                from: 1; to: 0
                duration: d.timeout
                running: d.timeout > 0
                paused: hover.containsMouse
                onFinished: Notifs.hideToast(d.nid)
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
            TapHandler {
                onTapped: { if (d.item && d.item.hasDefault) Notifs.invoke(d.nid, "default"); else Notifs.hideToast(d.nid) }
            }
        }

        add: Transition {
            enabled: Theme.animations
            ParallelAnimation {
                NumberAnimation { property: "x"; from: 60; to: 0; duration: Theme.dur(280); easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur(200) }
            }
        }
        remove: Transition {
            enabled: Theme.animations
            ParallelAnimation {
                NumberAnimation { property: "x"; to: 80; duration: Theme.dur(200); easing.type: Easing.InCubic }
                NumberAnimation { property: "opacity"; to: 0; duration: Theme.dur(180) }
            }
        }
        displaced: Transition {
            enabled: Theme.animations
            NumberAnimation { property: "y"; duration: Theme.dur(240); easing.type: Easing.OutCubic }
        }
    }
}
