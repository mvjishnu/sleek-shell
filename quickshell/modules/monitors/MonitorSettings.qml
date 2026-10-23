import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// SUPER + SHIFT + D: monitor settings (resolution, refresh rate, scale, position, rotation).
// Values come from the live Hyprland monitor list. Changes are applied at runtime first, with a
// 15 s countdown: "Keep" persists them to monitors_custom.lua (never the nwg-displays files),
// anything else — or no answer — restores the previous settings.
Scope {
    id: ms

    property bool open: false
    property var screenObj: null
    property var mons: []            // [{name, w, h, rr, x, y, scale, transform, modes:[{res,hz}], ...}]
    property string sel: ""
    property var pend: ({})          // pending values for the selected monitor
    property var snapshot: null      // values to restore on revert
    property int countdown: 0
    property string msg: ""
    property bool bad: false

    function collect() {
        var out = [], v = Wm.monList()
        for (var i = 0; i < v.length; ++i) {
            var o = v[i].lastIpcObject || ({}), modes = [], seen = ({})
            var am = o.availableModes || []
            for (var j = 0; j < am.length; ++j) {
                var mm = String(am[j]).match(/^(\d+x\d+)@([\d.]+)Hz$/)
                if (mm) modes.push({ res: mm[1], hz: mm[2] })
            }
            out.push({ name: v[i].name, w: o.width, h: o.height, rr: Math.round((o.refreshRate || 0) * 100) / 100,
                       x: o.x || 0, y: o.y || 0, scale: o.scale || 1, transform: o.transform || 0, modes: modes })
        }
        mons = out
    }
    function cur(name) { for (var i = 0; i < mons.length; ++i) if (mons[i].name === name) return mons[i]; return null }
    function resList(m) { var r = [], s = ({}); m.modes.forEach(function (x) { if (!s[x.res]) { s[x.res] = 1; r.push(x.res) } }); return r }
    function hzList(m, res) { return m.modes.filter(function (x) { return x.res === res }).map(function (x) { return x.hz }) }
    function pickSel(n) {
        sel = n
        var m = cur(n)
        pend = { res: m.w + "x" + m.h, hz: nearestHz(m, m.w + "x" + m.h, m.rr), scale: m.scale, transform: m.transform, x: m.x, y: m.y }
        msg = ""
    }
    function nearestHz(m, res, want) {
        var l = hzList(m, res), best = l.length ? l[0] : String(want), d = 1e9
        for (var i = 0; i < l.length; ++i) if (Math.abs(parseFloat(l[i]) - want) < d) { d = Math.abs(parseFloat(l[i]) - want); best = l[i] }
        return best
    }
    function logical(w, h, scale, tr) { if (tr % 2 === 1) { var t = w; w = h; h = t } return { w: w / scale, h: h / scale } }
    function setP(k, v) { var p = JSON.parse(JSON.stringify(pend)); p[k] = v; if (k === "res") p.hz = nearestHz(cur(sel), v, parseFloat(p.hz)); pend = p }

    // place relative to another monitor (right/left/above/below), top/left aligned
    function arrange(where, other) {
        var m = cur(sel), p = pend, o = cur(other)
        var L = logical(parseInt(p.res.split("x")[0]), parseInt(p.res.split("x")[1]), p.scale, p.transform)
        var O = logical(o.w, o.h, o.scale, o.transform)
        var x = o.x, y = o.y
        if (where === "right") x = o.x + Math.round(O.w)
        else if (where === "left") x = o.x - Math.round(L.w)
        else if (where === "below") y = o.y + Math.round(O.h)
        else if (where === "above") y = o.y - Math.round(L.h)
        var q = JSON.parse(JSON.stringify(pend)); q.x = x; q.y = y; pend = q
    }
    function validate() {
        var m = cur(sel), p = pend
        if (resList(m).indexOf(p.res) < 0) return "Resolution is not supported by this monitor"
        if (hzList(m, p.res).indexOf(p.hz) < 0) return "Refresh rate is not available at " + p.res
        var s = parseFloat(p.scale)
        if (!(s >= 0.5 && s <= 4)) return "Scale must be between 0.5 and 4"
        var sz = p.res.split("x").map(Number), L = logical(sz[0], sz[1], s, p.transform)
        var r = { x: parseInt(p.x), y: parseInt(p.y), w: L.w, h: L.h }
        for (var i = 0; i < mons.length; ++i) {
            if (mons[i].name === sel) continue
            var o = mons[i], O = logical(o.w, o.h, o.scale, o.transform)
            if (r.x < o.x + O.w && r.x + r.w > o.x && r.y < o.y + O.h && r.y + r.h > o.y) return "Overlaps " + o.name + " — pick another position"
        }
        return ""
    }
    function ruleOf(name, p) {
        return 'hl.monitor({ output = "' + Wm.safe(name) + '", mode = "' + p.res + '@' + p.hz + '", position = "' + parseInt(p.x) + 'x' + parseInt(p.y) +
               '", scale = ' + parseFloat(p.scale) + ', transform = ' + parseInt(p.transform) + ' })'
    }
    function apply() {
        var e = validate()
        if (e) { msg = e; bad = true; return }
        var m = cur(sel)
        snapshot = { name: sel, p: { res: m.w + "x" + m.h, hz: String(m.rr), scale: m.scale, transform: m.transform, x: m.x, y: m.y } }
        // keep exact refresh text of the CURRENT mode for the revert rule
        snapshot.p.hz = nearestHz(m, snapshot.p.res, m.rr)
        Wm.lua(ruleOf(sel, pend))
        countdown = 15; msg = ""; ticker.restart()
        refreshT.restart()
    }
    function revert() {
        ticker.stop(); countdown = 0
        if (snapshot) { Wm.lua(ruleOf(snapshot.name, snapshot.p)); msg = "Reverted to the previous settings"; bad = false }
        snapshot = null
        refreshT.restart()
    }
    function keep() {
        ticker.stop(); countdown = 0
        var p = pend, o = ({})
        o[sel] = { mode: p.res + "@" + p.hz, position: parseInt(p.x) + "x" + parseInt(p.y), scale: parseFloat(p.scale), transform: parseInt(p.transform) }
        save.command = ["python3", Wm.home + "/.config/hypr/scripts/hypr-tools.py", "save-monitors", JSON.stringify(o)]
        save.running = true
        snapshot = null
    }
    Process {
        id: save
        stdout: StdioCollector { onStreamFinished: { try { var r = JSON.parse(text); ms.msg = r.ok ? "Saved to monitors_custom.lua" : "Save failed: " + r.error; ms.bad = !r.ok } catch (e) { ms.msg = "Save failed"; ms.bad = true } } }
    }
    Timer { id: ticker; interval: 1000; repeat: true; onTriggered: { ms.countdown--; if (ms.countdown <= 0) ms.revert() } }
    Timer { id: refreshT; interval: 700; onTriggered: { Wm.refreshAll(); collectT.restart() } }
    Timer { id: collectT; interval: 250; onTriggered: { ms.collect(); if (ms.snapshot === null && ms.sel !== "") ms.pickSel(ms.sel) } }

    function show() {
        Wm.refreshAll()
        collect()
        var s = Quickshell.screens, f = Wm.focusedMon()
        screenObj = s[0]
        for (var i = 0; i < s.length; ++i) if (s[i].name === f) screenObj = s[i]
        pickSel(mons.some(function (m) { return m.name === f }) ? f : mons[0].name)
        open = true
        t0.restart()
    }
    function hide() { if (snapshot) revert(); open = false }
    Timer { id: t0; interval: 150; onTriggered: { ms.collect(); keys.forceActiveFocus() } }

    GlobalShortcut { name: "monitors-toggle"; description: "Monitor settings"; onPressed: ms.open ? ms.hide() : ms.show() }
    IpcHandler { target: "monitors"; function toggle(): void { ms.open ? ms.hide() : ms.show() } }

    PanelWindow {
        visible: ms.open
        screen: ms.screenObj
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        FocusScope {
            id: keys
            anchors.fill: parent; focus: true
            Keys.onPressed: e => { if (e.key === Qt.Key_Escape) ms.hide(); e.accepted = true }
            Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.45) }
            MouseArea { anchors.fill: parent; onClicked: ms.hide() }

            Rectangle {
                anchors.centerIn: parent
                width: 640; height: body.height + Theme.pad * 2
                radius: Theme.radius; border.width: Theme.strokeWidth; border.color: Theme.stroke
                gradient: Gradient { GradientStop { position: 0; color: Theme.glassPopTop } GradientStop { position: 1; color: Theme.glassPopBottom } }
                MouseArea { anchors.fill: parent }
                Column {
                    id: body
                    x: Theme.pad; y: Theme.pad; width: parent.width - Theme.pad * 2; spacing: 12
                    Text { text: "Monitor settings"; color: Theme.text; font.family: Theme.font; font.pixelSize: 16; font.bold: true }

                    Flow {
                        width: parent.width; spacing: 8
                        Repeater { model: ms.mons; delegate: UiBtn { required property var modelData; label: modelData.name; selected: ms.sel === modelData.name; onClicked: ms.pickSel(modelData.name) } }
                    }

                    Column {
                        width: parent.width; spacing: 10
                        visible: ms.cur(ms.sel) !== null
                        Text { text: "Resolution"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                        Flow { width: parent.width; spacing: 6
                            Repeater { model: ms.cur(ms.sel) ? ms.resList(ms.cur(ms.sel)) : []; delegate: UiBtn { required property string modelData; label: modelData; selected: ms.pend.res === modelData; onClicked: ms.setP("res", modelData) } } }
                        Text { text: "Refresh rate"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                        Flow { width: parent.width; spacing: 6
                            Repeater { model: ms.cur(ms.sel) && ms.pend.res ? ms.hzList(ms.cur(ms.sel), ms.pend.res) : []; delegate: UiBtn { required property string modelData; label: modelData + " Hz"; selected: ms.pend.hz === modelData; onClicked: ms.setP("hz", modelData) } } }
                        Text { text: "Scale"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                        Flow { width: parent.width; spacing: 6
                            Repeater { model: [1, 1.25, 1.5, 1.75, 2]; delegate: UiBtn { required property var modelData; label: modelData + "×"; selected: Math.abs(parseFloat(ms.pend.scale) - modelData) < 0.001; onClicked: ms.setP("scale", modelData) } } }
                        Text { text: "Rotation"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                        Flow { width: parent.width; spacing: 6
                            Repeater { model: [{ l: "Normal", v: 0 }, { l: "90°", v: 1 }, { l: "180°", v: 2 }, { l: "270°", v: 3 }]; delegate: UiBtn { required property var modelData; label: modelData.l; selected: ms.pend.transform === modelData.v; onClicked: ms.setP("transform", modelData.v) } } }
                        Text { text: "Position  (" + ms.pend.x + ", " + ms.pend.y + ")"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                        Flow { width: parent.width; spacing: 6
                            Repeater {
                                model: { var r = []; ms.mons.forEach(function (o) { if (o.name !== ms.sel) ["right", "left", "above", "below"].forEach(function (w) { r.push({ w: w, o: o.name }) }) }); return r }
                                delegate: UiBtn { required property var modelData; label: modelData.w + " of " + modelData.o; onClicked: ms.arrange(modelData.w, modelData.o) }
                            } }
                    }

                    Text {
                        visible: ms.msg !== ""
                        width: parent.width; wrapMode: Text.WordWrap
                        text: ms.msg; color: ms.bad ? Theme.red : Theme.green; font.family: Theme.font; font.pixelSize: 12
                    }
                    Text {
                        visible: ms.countdown > 0
                        text: "Keeping these settings? Reverting in " + ms.countdown + " s…"
                        color: Theme.yellow; font.family: Theme.font; font.pixelSize: 13; font.bold: true
                    }
                    Row {
                        spacing: 8
                        UiBtn { visible: ms.countdown === 0; label: "Apply (test 15 s)"; selected: true; onClicked: ms.apply() }
                        UiBtn { visible: ms.countdown > 0; label: "Keep changes"; selected: true; onClicked: ms.keep() }
                        UiBtn { visible: ms.countdown > 0; label: "Revert now"; danger: true; onClicked: ms.revert() }
                        UiBtn { visible: ms.countdown === 0; label: "Close"; onClicked: ms.hide() }
                    }
                }
            }
        }
    }
}
