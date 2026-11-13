import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.services
import qs.components

// SUPER + TAB: compact, monitor-grouped workspace strip with app icons and drag/drop.
Scope {
    id: ov

    property bool open: false
    property var screenObj: null
    property var model: []
    property int selMon: 0
    property int selIdx: 0
    property string status: ""
    property bool statusBad: false
    // drag state
    property bool dragging: false
    property var dragWin: null
    property var moveMenuWin: null
    property string hoverKey: ""
    property var cards: ({})
    property var pending: null

    function screenFor(name) {
        var s = Quickshell.screens
        for (var i = 0; i < s.length; ++i) if (s[i].name === name) return s[i]
        return s.length ? s[0] : null
    }

    function build() {
        if (dragging) return
        var wins = Wm.windows(), res = [], ms = Wm.monList(), fm = Wm.focusedMon()
        for (var i = 0; i < ms.length; ++i) {
            var m = ms[i], o = m.lastIpcObject || ({})
            var sc = o.scale || 1, w = o.width || m.width, h = o.height || m.height
            if ((o.transform || 0) % 2 === 1) { var tmp = w; w = h; h = tmp }
            var act = Wm.activeWsId(m.name), ws = []
            var ids = Wm.wsIds(m.name), occupied = []
            for (var j = 0; j < ids.length; ++j) {
                var id = ids[j]
                var hasWindows = wins.some(function (x) { return x.wsId === id && x.mon === m.name && !x.special })
                if (id === act || hasWindows) occupied.push(id)
            }
            // Keep the active/occupied workspaces and expose exactly one empty
            // destination so the strip can grow naturally as workspaces are used.
            var extraId = -1
            for (var k = 0; k < ids.length; ++k) {
                if (occupied.indexOf(ids[k]) < 0) { extraId = ids[k]; break }
            }
            for (var j = 0; j < occupied.length; ++j) {
                var id = occupied[j]
                ws.push({ id: id, monitor: m.name, active: id === act, extra: false,
                          wins: wins.filter(function (x) { return x.wsId === id && x.mon === m.name && !x.minimized && !x.special }) })
            }
            if (extraId >= 0) ws.push({ id: extraId, monitor: m.name, active: false, extra: true, wins: [] })
            else ws.push({ id: "new", monitor: m.name, active: false, extra: true, wins: [] })
            res.push({ name: m.name, lw: w / sc, lh: h / sc, mx: o.x || 0, my: o.y || 0, focused: m.name === fm,
                       desc: Math.round(w) + "×" + Math.round(h) + " @ " + (Math.round((o.refreshRate || 0) * 10) / 10) + " Hz", ws: ws })
        }
        model = res
        if (model.length) {
            selMon = Math.max(0, Math.min(model.length - 1, selMon))
            selIdx = Math.max(0, Math.min(model[selMon].ws.length - 1, selIdx))
        }
    }

    function show() {
        screenObj = screenFor(Wm.focusedMon())
        status = ""; dragging = false; moveMenuWin = null; hoverKey = ""
        Wm.refreshAll()
        build()
        // start on the active workspace of the focused monitor
        for (var i = 0; i < model.length; ++i) if (model[i].focused) {
            selMon = i
            for (var j = 0; j < model[i].ws.length; ++j) if (model[i].ws[j].active) selIdx = j
        }
        Wm.watchers++
        open = true
        settle.restart()
    }
    function hide() {
        if (!open) return
        open = false; dragging = false; moveMenuWin = null
        Wm.watchers = Math.max(0, Wm.watchers - 1)
    }
    function toggle() { open ? hide() : show() }
    Timer { id: settle; interval: 140; onTriggered: { ov.build(); keys.forceActiveFocus() } }
    Connections { target: Wm; function onChanged() { if (ov.open) ov.build() } }
    Connections { target: Wm; function onAllocChanged() { if (ov.open) ov.build() } }

    // ---------------------------------------------------------------- actions
    function activateWs(id) { Wm.gotoWs(id); hide() }
    function newWs(mon) { Wm.createWs(mon, true); hide() }

    function cardAt(x, y) {
        for (var k in cards) {
            var it = cards[k]
            if (!it) continue
            var p = it.mapFromItem(keys, x, y)
            if (p.x >= 0 && p.y >= 0 && p.x <= it.width && p.y <= it.height) return k
        }
        return ""
    }
    function dropOn(key) {
        var w = dragWin
        dragging = false; dragWin = null; hoverKey = ""
        if (!key) { status = "Drag cancelled"; statusBad = false; build(); return }
        var parts = key.split("|"), mon = parts[0], target = parts[1]
        if (!Wm.hasWindow(w.address)) { status = "That window no longer exists"; statusBad = true; build(); return }
        if (target !== "new" && parseInt(target) === w.wsId && mon === w.mon) { status = ""; build(); return }
        if (target === "new") {
            pending = { addr: w.address, mon: mon, ws: Wm.alloc.next }
            Wm.moveToNewWs(w.address, mon)
        } else {
            pending = { addr: w.address, mon: mon, ws: parseInt(target) }
            Wm.moveWindow(w.address, target)
        }
        status = "Moving “" + w.title + "”…"; statusBad = false
        verify1.restart()
    }
    function cancelDrag() { dragging = false; dragWin = null; hoverKey = ""; status = "Drag cancelled"; statusBad = false; build() }

    // Check the destination against the real compositor state, not against the thumbnail.
    Timer { id: verify1; interval: 350; onTriggered: { Wm.refreshAll(); verify2.restart() } }
    Timer {
        id: verify2; interval: 250
        onTriggered: {
            var p = ov.pending; if (!p) return
            var ws = Wm.windows().filter(function (x) { return x.address === p.addr })
            var w = ws.length ? ws[0] : null
            if (w && w.wsId === p.ws && w.mon === p.mon) { ov.status = "✓ Moved “" + w.title + "” to workspace " + p.ws + " on " + p.mon; ov.statusBad = false }
            else { ov.status = "✗ Window is not at the destination (Hyprland reports " + (w ? "workspace " + w.wsId + " on " + w.mon : "no such window") + ")"; ov.statusBad = true }
            ov.pending = null; ov.build()
        }
    }

    function onKey(e) {
        var m = model[selMon]
        if (e.key === Qt.Key_Escape) { if (moveMenuWin) moveMenuWin = null; else if (dragging) cancelDrag(); else hide() }
        else if (!m) return
        else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) selIdx = Math.min(m.ws.length - 1, selIdx + 1)
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) selIdx = Math.max(0, selIdx - 1)
        else if (e.key === Qt.Key_Down) { selMon = Math.min(model.length - 1, selMon + 1); selIdx = Math.min(selIdx, model[selMon].ws.length) }
        else if (e.key === Qt.Key_Up) { selMon = Math.max(0, selMon - 1); selIdx = Math.min(selIdx, model[selMon].ws.length) }
        else if (e.key === Qt.Key_N) newWs(m.name)
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            var selectedWs = m.ws[selIdx]
            if (selectedWs && selectedWs.id === "new") newWs(m.name)
            else if (selectedWs) activateWs(selectedWs.id)
        }
        e.accepted = true
    }

    GlobalShortcut { name: "overview-toggle"; description: "Workspace overview"; onPressed: ov.toggle() }
    IpcHandler { target: "overview"; function toggle(): void { ov.toggle() } function open(): void { if (!ov.open) ov.show() } function close(): void { ov.hide() } }

    PanelWindow {
        id: win
        visible: ov.open
        screen: ov.screenObj
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
            Keys.onPressed: e => ov.onKey(e)

            Rectangle { z: -2; anchors.fill: parent; color: Theme.scrim; opacity: ov.open ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.durBase } } }
            // Keep the dismiss target underneath the workspace cards and their app icons.
            MouseArea { z: -1; anchors.fill: parent; onClicked: ov.hide() }

            WorkspaceStrip {
                z: 0
                anchors.fill: parent
                controller: ov
                keyScope: keys
                dragGhost: ghost
            }

            // Right-click an app icon to choose its destination explicitly.
            Rectangle {
                id: moveMenu
                visible: ov.moveMenuWin !== null
                z: 50
                anchors.centerIn: parent
                width: Math.min(500, parent.width - 32)
                height: Math.min(parent.height - 80, menuColumn.implicitHeight + 32)
                radius: Theme.radius
                color: Theme.surface
                border.width: Theme.strokeWidth
                border.color: Theme.border
                Column {
                    id: menuColumn
                    anchors { fill: parent; margins: 16 }
                    spacing: 10
                    Text {
                        width: parent.width
                        text: "Move “" + (ov.moveMenuWin ? ov.moveMenuWin.title : "") + "” to…"
                        color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontXl; font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Repeater {
                        model: ov.model
                        delegate: Column {
                            required property var modelData
                            width: menuColumn.width
                            spacing: 5
                            Text { text: modelData.name; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                            Flow {
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: modelData.ws
                                    delegate: UiBtn {
                                        required property var modelData
                                        required property int index
                                        label: modelData.active ? "Current" : (modelData.extra ? "Empty" : "Open")
                                        onClicked: {
                                            ov.dragWin = ov.moveMenuWin
                                            ov.moveMenuWin = null
                                            ov.dropOn(modelData.monitor + "|" + modelData.id)
                                        }
                                    }
                                }
                                UiBtn {
                                    label: "New workspace"
                                    onClicked: {
                                        ov.dragWin = ov.moveMenuWin
                                        ov.moveMenuWin = null
                                        ov.dropOn(modelData.name + "|new")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 26 }
                text: ov.status !== "" ? ov.status : "←→ select · ↑↓ monitor · Enter switch · N new workspace · drag app icons · Esc close"
                color: ov.statusBad ? Theme.red : (ov.status !== "" ? Theme.green : Theme.muted)
                font.family: Theme.font; font.pixelSize: 13
            }

            // drag ghost
            Rectangle {
                id: ghost
                visible: ov.dragging
                z: 100
                width: 170; height: 30; radius: 8
                color: Qt.alpha(Theme.accent, 0.85)
                border.width: Theme.strokeWidth; border.color: Theme.text
                Text { anchors.centerIn: parent; width: parent.width - 12; elide: Text.ElideRight; text: ov.dragWin ? ov.dragWin.title : ""; color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
            }
        }
    }
}
