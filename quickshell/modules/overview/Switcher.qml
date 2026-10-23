import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// ALT + TAB application switcher. Context = the focused monitor: every window on any workspace
// of that monitor (plus windows hidden from it), most recently used first. Each window is its own
// entry, even several of the same app. Confirming focuses (or restores) the EXISTING window; it
// never launches anything. Other monitors are unaffected.
Scope {
    id: sw

    property bool open: false
    property var screenObj: null
    property string monName: ""
    property var items: []
    property int idx: 0

    function collect() {
        var mon = Wm.focusedMon(), wins = Wm.windows().filter(function (w) { return w.mon === mon && !w.special })
        var rank = ({})
        for (var i = 0; i < Wm.mru.length; ++i) rank[Wm.mru[i]] = i
        wins.sort(function (a, b) {
            var ra = rank[a.address] === undefined ? 999 : rank[a.address], rb = rank[b.address] === undefined ? 999 : rank[b.address]
            return ra - rb
        })
        monName = mon
        return wins
    }
    function step(d) {
        if (!open) {
            Wm.refreshAll()
            items = collect()
            if (items.length === 0) return
            var s = Quickshell.screens, sc = null
            for (var i = 0; i < s.length; ++i) if (s[i].name === monName) sc = s[i]
            screenObj = sc || s[0]
            idx = d > 0 ? (items.length > 1 ? 1 : 0) : items.length - 1
            Wm.watchers++
            open = true
            focusTimer.restart()
        } else {
            idx = (idx + d + items.length) % items.length
        }
    }
    function close() { if (open) { open = false; Wm.watchers = Math.max(0, Wm.watchers - 1) } }
    function confirm() {
        var w = items[idx]
        close()
        // stale check: the window may have closed while the switcher was open
        if (w && Wm.hasWindow(w.address)) Wm.activate(w)
    }
    // drop entries whose windows disappeared while open
    Connections {
        target: Wm
        function onChanged() {
            if (!sw.open) return
            var alive = sw.items.filter(function (w) { return Wm.hasWindow(w.address) })
            if (alive.length !== sw.items.length) { sw.items = alive; sw.idx = Math.min(sw.idx, Math.max(0, alive.length - 1)); if (alive.length === 0) sw.close() }
        }
    }
    Timer { id: focusTimer; interval: 30; onTriggered: keys.forceActiveFocus() }

    GlobalShortcut { name: "switcher-next"; description: "Application switcher: next"; onPressed: sw.step(1) }
    GlobalShortcut { name: "switcher-prev"; description: "Application switcher: previous"; onPressed: sw.step(-1) }
    GlobalShortcut { name: "minimize"; description: "Hide the focused window"; onPressed: Wm.minimizeActive() }
    IpcHandler { target: "switcher"; function next(): void { sw.step(1) } function prev(): void { sw.step(-1) } function confirm(): void { sw.confirm() } function cancel(): void { sw.close() } }

    PanelWindow {
        visible: sw.open
        screen: sw.screenObj
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) sw.close()
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) sw.confirm()
                else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Right) sw.step(1)
                else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left) sw.step(-1)
                e.accepted = true
            }
            // releasing Alt confirms, like a normal Alt+Tab
            Keys.onReleased: e => { if (e.key === Qt.Key_Alt) { sw.confirm(); e.accepted = true } }

            MouseArea { anchors.fill: parent; onClicked: sw.close() }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, strip.width + Theme.pad * 2)
                height: 210 + Theme.pad
                radius: Theme.radius
                border.width: Theme.strokeWidth; border.color: Theme.stroke
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.glassPopTop }
                    GradientStop { position: 1; color: Theme.glassPopBottom }
                }
                Text {
                    x: Theme.pad; y: 8
                    text: sw.monName + "  ·  " + (sw.items[sw.idx] ? sw.items[sw.idx].title : "")
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
                    width: parent.width - Theme.pad * 2; elide: Text.ElideRight
                }
                Row {
                    id: strip
                    anchors { centerIn: parent; verticalCenterOffset: 8 }
                    spacing: 10
                    Repeater {
                        model: sw.items
                        delegate: Rectangle {
                            id: it
                            required property var modelData
                            required property int index
                            width: 170; height: 170; radius: 12
                            color: sw.idx === index ? Qt.alpha(Theme.accent, 0.28) : (ma.containsMouse ? Theme.surfaceHi : Theme.surface)
                            border.width: sw.idx === index ? 2 : 1
                            border.color: sw.idx === index ? Theme.accent : Theme.border
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            ScreencopyView {
                                x: 8; y: 8; width: parent.width - 16; height: 100
                                captureSource: it.modelData.minimized ? null : it.modelData.toplevel.wayland
                                live: false
                            }
                            Image {
                                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 42 }
                                width: 36; height: 36; source: it.modelData.icon; sourceSize: Qt.size(72, 72)
                                opacity: it.modelData.minimized ? 0.5 : 0.9
                            }
                            Text {
                                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 116; margins: 8 }
                                text: it.modelData.title; elide: Text.ElideRight; color: Theme.text
                                font.family: Theme.font; font.pixelSize: 12; font.bold: true
                            }
                            Text {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
                                text: (it.modelData.minimized ? "hidden · " : "") + "workspace " + it.modelData.wsId + (it.modelData.floating ? " · floating" : "")
                                elide: Text.ElideRight
                                color: it.modelData.minimized ? Theme.yellow : Theme.muted; font.family: Theme.font; font.pixelSize: 10
                            }
                            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: { sw.idx = it.index; sw.confirm() } }
                        }
                    }
                }
            }
        }
    }
}
