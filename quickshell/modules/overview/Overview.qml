import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.services
import qs.components

// SUPER + TAB: workspace overview. One row per monitor (real Hyprland monitors/workspaces),
// window thumbnails placed where the windows really are. Drag a window onto another workspace
// card (same or other monitor) or onto "+" to move the REAL window; the result is verified
// against Hyprland afterwards.
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
            var ids = Wm.wsIds(m.name)
            for (var j = 0; j < ids.length; ++j) {
                var id = ids[j]
                ws.push({ id: id, active: id === act, wins: wins.filter(function (x) { return x.wsId === id && x.mon === m.name && !x.minimized && !x.special }) })
            }
            res.push({ name: m.name, lw: w / sc, lh: h / sc, mx: o.x || 0, my: o.y || 0, focused: m.name === fm,
                       desc: Math.round(w) + "×" + Math.round(h) + " @ " + (Math.round((o.refreshRate || 0) * 10) / 10) + " Hz", ws: ws })
        }
        model = res
    }

    function show() {
        screenObj = screenFor(Wm.focusedMon())
        status = ""; dragging = false; hoverKey = ""
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
        open = false; dragging = false
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
        if (e.key === Qt.Key_Escape) { dragging ? cancelDrag() : hide() }
        else if (!m) return
        else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) selIdx = Math.min(m.ws.length, selIdx + 1)
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) selIdx = Math.max(0, selIdx - 1)
        else if (e.key === Qt.Key_Down) { selMon = Math.min(model.length - 1, selMon + 1); selIdx = Math.min(selIdx, model[selMon].ws.length) }
        else if (e.key === Qt.Key_Up) { selMon = Math.max(0, selMon - 1); selIdx = Math.min(selIdx, model[selMon].ws.length) }
        else if (e.key === Qt.Key_N) newWs(m.name)
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { selIdx >= m.ws.length ? newWs(m.name) : activateWs(m.ws[selIdx].id) }
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

            Rectangle { anchors.fill: parent; color: Theme.scrim; opacity: ov.open ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.durBase } } }
            MouseArea { anchors.fill: parent; onClicked: ov.hide() }

            Flickable {
                anchors { fill: parent; margins: 40; bottomMargin: 70 }
                contentHeight: col.height
                contentWidth: width
                clip: true
                interactive: !ov.dragging
                Column {
                    id: col
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 26
                    Repeater {
                        model: ov.model
                        delegate: Rectangle {
                            id: sec
                            required property var modelData
                            required property int index
                            width: row.width + Theme.pad * 2
                            height: row.height + 56
                            radius: Theme.radius
                            border.width: Theme.strokeWidth
                            border.color: modelData.focused ? Theme.accent : Theme.border
                            gradient: Gradient {
                                GradientStop { position: 0; color: Theme.glassPopTop }
                                GradientStop { position: 1; color: Theme.glassPopBottom }
                            }
                            MouseArea { anchors.fill: parent }   // swallow clicks so the backdrop does not close
                            Text {
                                x: Theme.pad; y: 12
                                text: sec.modelData.name + "   " + sec.modelData.desc + (sec.modelData.focused ? "   · focused" : "")
                                color: Theme.text; font.family: Theme.font; font.pixelSize: 13; font.bold: true
                            }
                            Row {
                                id: row
                                x: Theme.pad; y: 40
                                spacing: 14
                                Repeater {
                                    model: sec.modelData.ws
                                    delegate: Rectangle {
                                        id: card
                                        required property var modelData
                                        required property int index
                                        readonly property string key: sec.modelData.name + "|" + modelData.id
                                        readonly property real cw: 230
                                        readonly property real k: cw / sec.modelData.lw
                                        width: cw; height: Math.max(90, sec.modelData.lh * k)
                                        radius: 10; clip: true
                                        color: ov.hoverKey === key ? Qt.alpha(Theme.accent, 0.28) : (cardMa.containsMouse ? Theme.surfaceHi : Theme.surface)
                                        border.width: (ov.selMon === sec.index && ov.selIdx === index) || ov.hoverKey === key ? 2 : 1
                                        border.color: (ov.selMon === sec.index && ov.selIdx === index) || ov.hoverKey === key ? Theme.accent : Theme.border
                                        Component.onCompleted: ov.cards[key] = card
                                        Component.onDestruction: delete ov.cards[key]
                                        MouseArea {
                                            id: cardMa; anchors.fill: parent; hoverEnabled: true
                                            onClicked: ov.activateWs(card.modelData.id)
                                        }
                                        Text {
                                            anchors { left: parent.left; bottom: parent.bottom; margins: 6 }
                                            text: card.modelData.id + (card.modelData.active ? "  ● active" : "") + (card.modelData.wins.length === 0 ? "  (empty)" : "")
                                            color: card.modelData.active ? Theme.accent : Theme.muted
                                            font.family: Theme.font; font.pixelSize: 11
                                        }
                                        Repeater {
                                            model: card.modelData.wins
                                            delegate: Rectangle {
                                                id: wcard
                                                required property var modelData
                                                x: Math.max(0, (modelData.at[0] - sec.modelData.mx) * card.k)
                                                y: Math.max(0, (modelData.at[1] - sec.modelData.my) * card.k)
                                                width: Math.max(34, Math.min(card.cw - x, modelData.size[0] * card.k))
                                                height: Math.max(24, Math.min(card.height - y, modelData.size[1] * card.k))
                                                radius: 5; clip: true
                                                color: Qt.alpha(Theme.accent, wma.containsMouse ? 0.30 : 0.16)
                                                border.width: Theme.strokeWidth; border.color: Qt.alpha(Theme.accent, 0.6)
                                                opacity: ov.dragging && ov.dragWin && ov.dragWin.address === modelData.address ? 0.35 : 1
                                                ScreencopyView {
                                                    anchors.fill: parent
                                                    captureSource: wcard.modelData.toplevel.wayland
                                                    live: false
                                                }
                                                Image {
                                                    anchors.centerIn: parent; width: 22; height: 22
                                                    source: wcard.modelData.icon; sourceSize: Qt.size(44, 44)
                                                    visible: wcard.width > 40 && wcard.height > 40
                                                }
                                                Text {
                                                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 3 }
                                                    text: wcard.modelData.title; elide: Text.ElideRight
                                                    color: Theme.text; font.family: Theme.font; font.pixelSize: 9
                                                }
                                                MouseArea {
                                                    id: wma; anchors.fill: parent; hoverEnabled: true
                                                    property point start
                                                    property bool moved: false
                                                    cursorShape: ov.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                                    onPressed: m => { start = Qt.point(m.x, m.y); moved = false }
                                                    onPositionChanged: m => {
                                                        if (!pressed) return
                                                        if (!ov.dragging && (Math.abs(m.x - start.x) + Math.abs(m.y - start.y)) > 8) {
                                                            ov.dragWin = wcard.modelData; ov.dragging = true; moved = true
                                                        }
                                                        if (ov.dragging) {
                                                            var p = wma.mapToItem(keys, m.x, m.y)
                                                            ghost.x = p.x + 8; ghost.y = p.y + 8
                                                            ov.hoverKey = ov.cardAt(p.x, p.y)
                                                        }
                                                    }
                                                    onReleased: m => {
                                                        if (ov.dragging) { var p = wma.mapToItem(keys, m.x, m.y); ov.dropOn(ov.cardAt(p.x, p.y)) }
                                                        else { Wm.focusWindow(wcard.modelData.address); ov.hide() }
                                                    }
                                                    onCanceled: if (ov.dragging) ov.cancelDrag()
                                                }
                                            }
                                        }
                                    }
                                }
                                // "+" card: new workspace on this monitor (also a valid drop target)
                                Rectangle {
                                    id: plus
                                    readonly property string key: sec.modelData.name + "|new"
                                    width: 90; height: Math.max(90, sec.modelData.lh * 230 / sec.modelData.lw)
                                    radius: 10
                                    color: ov.hoverKey === key ? Qt.alpha(Theme.accent, 0.28) : (pma.containsMouse ? Theme.surfaceHi : "transparent")
                                    border.width: (ov.selMon === sec.index && ov.selIdx === sec.modelData.ws.length) || ov.hoverKey === key ? 2 : 1
                                    border.color: (ov.selMon === sec.index && ov.selIdx === sec.modelData.ws.length) || ov.hoverKey === key ? Theme.accent : Theme.border
                                    Component.onCompleted: ov.cards[key] = plus
                                    Component.onDestruction: delete ov.cards[key]
                                    Text { anchors.centerIn: parent; text: "＋\nnew"; horizontalAlignment: Text.AlignHCenter; color: Theme.muted; font.family: Theme.font; font.pixelSize: 14 }
                                    MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: ov.newWs(sec.modelData.name) }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 26 }
                text: ov.status !== "" ? ov.status : "←→↑↓ select · Enter switch · N new workspace · drag a window onto a workspace · Esc close"
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
