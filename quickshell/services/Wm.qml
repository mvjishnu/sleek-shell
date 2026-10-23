pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Window-manager helper shared by the overview, the switcher, minimise and bar scrolling.
// Live state comes from Quickshell.Hyprland; the per-monitor workspace allocation comes from
// the file owned by hypr/modules/workspace_state.lua. Commands go to Hyprland with
// `hyprctl dispatch` / `hyprctl eval` using the Lua API of the installed 0.56.
Singleton {
    id: wm

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateFile: home + "/.local/state/hyprland/workspaces.txt"
    readonly property string minFile: home + "/.local/state/quickshell/minimized.json"
    readonly property string minWs: "special:minimized"

    property var alloc: ({ next: 1, mons: ({}) })     // mons[name] = { def, ws: [ids] }
    property var minimized: ({})                      // address -> { ws, mon, title }
    property var mru: []                              // window addresses, most recent first
    property int watchers: 0                          // overlays currently open (event-driven refresh only then)
    signal changed()

    // ---------------------------------------------------------------- state files
    FileView {
        path: wm.stateFile
        watchChanges: true
        printErrors: false
        onLoaded: wm.parseAlloc(text())
        onFileChanged: reload()
    }
    FileView {
        id: minStore
        path: wm.minFile
        printErrors: false
        atomicWrites: true
        onLoaded: { try { wm.minimized = JSON.parse(text()) } catch (e) { wm.minimized = ({}) } }
    }
    Process { id: mkdir; command: ["mkdir", "-p", wm.home + "/.local/state/quickshell"]; running: true }

    function parseAlloc(t) {
        var a = { next: 1, mons: ({}) }
        var lines = t.split("\n")
        for (var i = 0; i < lines.length; ++i) {
            var p = lines[i].trim().split(/\s+/)
            if (p[0] === "next") a.next = parseInt(p[1])
            else if (p[0] === "m") { a.mons[p[1]] = a.mons[p[1]] || { def: parseInt(p[2]), ws: [] }; a.mons[p[1]].def = parseInt(p[2]) }
            else if (p[0] === "w") { a.mons[p[1]] = a.mons[p[1]] || { def: parseInt(p[2]), ws: [] }; a.mons[p[1]].ws.push(parseInt(p[2])) }
        }
        wm.alloc = a
    }

    // ---------------------------------------------------------------- queries
    function addr(t) { var a = String(t.address); return a.indexOf("0x") === 0 ? a : "0x" + a }
    function monList() { return Hyprland.monitors.values }
    function focusedMon() { return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "" }
    function monByName(n) {
        var v = monList()
        for (var i = 0; i < v.length; ++i) if (v[i].name === n) return v[i]
        return null
    }
    function connected(n) { return monByName(n) !== null }

    // Workspace ids of a monitor, in display order: allocated ones first, then any live ones.
    function wsIds(mon) {
        var ids = []
        var m = alloc.mons[mon]
        if (m) ids = m.ws.slice()
        var v = Hyprland.workspaces.values
        var extra = []
        for (var i = 0; i < v.length; ++i) {
            var w = v[i]
            if (w.id > 0 && w.monitor && w.monitor.name === mon && ids.indexOf(w.id) < 0) extra.push(w.id)
        }
        extra.sort(function (a, b) { return a - b })
        return ids.concat(extra)
    }
    function activeWsId(mon) {
        var m = monByName(mon)
        return m && m.activeWorkspace ? m.activeWorkspace.id : -1
    }
    function iconFor(cls) {
        var e = DesktopEntries.heuristicLookup(cls)
        return Quickshell.iconPath(e && e.icon ? e.icon : String(cls).toLowerCase(), "application-x-executable")
    }

    // All real windows as plain records. Hidden (minimised) windows report their ORIGINAL
    // workspace/monitor from the persisted record. Stale records are pruned here.
    function windows() {
        var out = [], seen = ({}), v = Hyprland.toplevels.values
        for (var i = 0; i < v.length; ++i) {
            var t = v[i], o = t.lastIpcObject || ({})
            if (o.mapped === false) continue
            var a = addr(t); seen[a] = true
            var ws = t.workspace
            var wsName = ws ? ws.name : (o.workspace ? o.workspace.name : "")
            var wsId = ws ? ws.id : (o.workspace ? o.workspace.id : -1)
            var isMin = wsName === wm.minWs
            var rec = minimized[a]
            var mon = (isMin && rec) ? rec.mon : (ws && ws.monitor ? ws.monitor.name : "")
            var cls = o.class || o.initialClass || ""
            out.push({
                address: a, title: t.title || o.title || cls, cls: cls, icon: iconFor(cls),
                wsId: (isMin && rec) ? rec.ws : wsId, mon: mon, minimized: isMin,
                floating: !!o.floating, at: o.at || [0, 0], size: o.size || [100, 100],
                special: wsId < 0 && !isMin, toplevel: t
            })
        }
        var stale = false, copy = ({})
        for (var k in minimized) { if (seen[k]) copy[k] = minimized[k]; else stale = true }
        if (stale) setMin(copy)
        return out
    }
    function hasWindow(a) {
        var v = Hyprland.toplevels.values
        for (var i = 0; i < v.length; ++i) if (addr(v[i]) === a) return true
        return false
    }

    // ---------------------------------------------------------------- commands
    function disp(expr) { Quickshell.execDetached(["hyprctl", "dispatch", expr]) }
    function batch(exprs) {
        Quickshell.execDetached(["hyprctl", "--batch", exprs.map(function (e) { return "dispatch " + e }).join(" ; ")])
    }
    function lua(code) { Quickshell.execDetached(["hyprctl", "eval", code]) }
    function safe(s) { return String(s).replace(/[^A-Za-z0-9_.:\-]/g, "") }

    function gotoWs(id) { disp('hl.dsp.focus({ workspace = "' + id + '" })') }
    function focusWindow(a) { disp('hl.dsp.focus({ window = "address:' + a + '" })') }
    function moveExpr(a, ws, follow) {
        return 'hl.dsp.window.move({ workspace = "' + ws + '", window = "address:' + a + '", follow = ' + (follow ? "true" : "false") + ' })'
    }
    function moveWindow(a, ws) { disp(moveExpr(a, ws, false)) }
    function createWs(mon, focus) {
        lua("require('modules.workspace_state')." + (focus ? "create_and_focus" : "create_and_focus") + "('" + safe(mon) + "')")
    }
    // Create a workspace on `mon` and move `a` into it, in one Lua call (new id is allocated by workspace_state).
    function moveToNewWs(a, mon) {
        var m = safe(mon)
        lua("local s=require('modules.workspace_state'); local st=s.load(); local id=s.create(st,'" + m + "'); " +
            "s.apply_rule(id,'" + m + "',false); s.write(st); " +
            "hl.dispatch(hl.dsp.window.move({ workspace = tostring(id), window = 'address:" + a + "', follow = false }))")
    }

    // Monitor-scoped navigation: index N means "the Nth workspace of THIS monitor".
    function gotoNth(n, mon) {
        mon = mon || focusedMon()
        var ids = wsIds(mon)
        if (n <= ids.length) gotoWs(ids[n - 1])
        else if (n === ids.length + 1) createWs(mon, true)
    }
    function moveActiveNth(n, mon) {
        mon = mon || focusedMon()
        var ids = wsIds(mon)
        if (n <= ids.length) disp('hl.dsp.window.move({ workspace = "' + ids[n - 1] + '" })')
    }
    function stepWs(mon, d) {
        mon = mon || focusedMon()
        var ids = wsIds(mon)
        if (ids.length < 2) return
        var i = ids.indexOf(activeWsId(mon))
        i = i < 0 ? 0 : (i + d + ids.length) % ids.length
        gotoWs(ids[i])
    }

    // ---------------------------------------------------------------- minimise / restore
    function setMin(m) { wm.minimized = m; minStore.setText(JSON.stringify(m)) }
    function minimizeActive() {
        var t = Hyprland.activeToplevel
        if (t) minimizeWindow(t)
    }
    function minimizeWindow(t) {
        var ws = t.workspace
        if (!ws || ws.id < 0) return                       // already special / unknown: leave alone
        var a = addr(t), m = JSON.parse(JSON.stringify(minimized))
        m[a] = { ws: ws.id, mon: ws.monitor ? ws.monitor.name : focusedMon(), title: t.title || "", time: Date.now() }
        setMin(m)
        disp(moveExpr(a, wm.minWs, false))
    }
    function restoreWindow(a) {
        var rec = minimized[a], target = -1
        if (rec && connected(rec.mon) && wsIds(rec.mon).indexOf(rec.ws) >= 0) target = rec.ws
        else target = activeWsId(focusedMon())             // original location is gone: use the current monitor
        var m = JSON.parse(JSON.stringify(minimized)); delete m[a]; setMin(m)
        batch([moveExpr(a, target, false), 'hl.dsp.focus({ workspace = "' + target + '" })', 'hl.dsp.focus({ window = "address:' + a + '" })'])
    }
    function activate(w) {
        if (w.minimized) restoreWindow(w.address)
        else focusWindow(w.address)
    }

    // ---------------------------------------------------------------- refresh + MRU
    function refreshAll() { Hyprland.refreshMonitors(); Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels() }
    Timer { id: debounce; interval: 90; onTriggered: wm.changed() }
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (wm.watchers > 0) debounce.restart() }
        function onActiveToplevelChanged() {
            var t = Hyprland.activeToplevel
            if (!t) return
            var a = wm.addr(t), l = wm.mru.filter(function (x) { return x !== a })
            l.unshift(a)
            wm.mru = l.slice(0, 64)
        }
    }
}
