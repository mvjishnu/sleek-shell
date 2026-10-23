pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Downloadable fonts, icon themes and cursor themes (scripts/asset-store.py). One download runs at a
// time from a queue; after each one the installed lists (Settings.desktopInfo) and fonts refresh.
Singleton {
    id: lib
    readonly property string script: Quickshell.shellDir + "/scripts/asset-store.py"

    // ---- catalogue
    property var fonts: []            // [{ f: family, c: sans|serif|hand|display|mono, p: popularity rank, s: styles, i: installed }]
    property var fontCounts: ({})
    property var icons: []            // [{ id, name, desc, tone, mb, script, installed, themes }]
    property var cursors: []
    property var starter: ({ fonts: [], icons: [], cursors: [] })
    property var dirs: ({ fonts: "", icons: "" })
    property bool loaded: false
    property bool loading: false
    property string catalogError: ""
    function load(refresh) {
        if (catalogProc.running) return
        loading = true
        catalogProc.command = ["python3", script, "catalog"].concat(refresh ? ["--refresh"] : [])
        catalogProc.running = true
    }
    function ensureLoaded() { if (!loaded && !loading) load(false) }
    Process {
        id: catalogProc
        stdout: StdioCollector { id: catalogOut }
        onExited: code => {
            lib.loading = false
            try {
                var o = JSON.parse(catalogOut.text)
                if (!o.ok) { lib.catalogError = o.error || "Could not load the catalogue"; return }
                lib.fonts = o.fonts; lib.fontCounts = o.fontCounts; lib.icons = o.icons; lib.cursors = o.cursors
                lib.starter = o.starter; lib.dirs = o.dirs; lib.loaded = true; lib.catalogError = ""
            } catch (e) { lib.catalogError = "Could not load the catalogue (asset-store.py exit " + code + ")" }
        }
    }

    // ---- install queue: { kind: font|icon|cursor|path|remove, arg, arg2, label }
    property var queue: []
    property var current: null
    property int doneCount: 0
    property int totalCount: 0
    property var pendingKeys: ({})    // "kind:arg" -> true while queued or running
    property string message: ""
    property bool messageError: false
    property var failures: []
    readonly property bool busy: current !== null
    readonly property real progress: totalCount > 0 ? doneCount / totalCount : 0

    function key(kind, arg) { return kind + ":" + arg }
    function isPending(kind, arg) { return !!pendingKeys[key(kind, arg)] }
    function enqueue(job) {
        var k = key(job.kind, job.arg)
        if (pendingKeys[k]) return
        var p = Object.assign({}, pendingKeys); p[k] = true; pendingKeys = p
        queue = queue.concat([job])
        if (!busy) { doneCount = 0; totalCount = 0; failures = [] }
        totalCount += 1
        next()
    }
    function installFont(family) { enqueue({ kind: "font", arg: family, label: family }) }
    function installIcon(e) { enqueue({ kind: "icon", arg: e.id, label: e.name + " icons" }) }
    function installCursor(e) { enqueue({ kind: "cursor", arg: e.id, label: e.name + " cursor" }) }
    function installPath(path) {
        var p = String(path || "").trim()
        if (p === "") { message = "Paste a file path, folder or download link first"; messageError = true; return }
        enqueue({ kind: "path", arg: p, label: p.split("/").pop() || p })
    }
    function remove(kind, name) { enqueue({ kind: "remove", arg: kind + "/" + name, kind2: kind, name: name, label: "Removing " + name }) }
    function installedFamily(f) { return Theme.fontList.indexOf(f) >= 0 || fonts.some(function (x) { return x.f === f && x.i }) }
    function starterMissing() {
        var miss = []
        starter.fonts.forEach(function (f) { if (!installedFamily(f)) miss.push({ kind: "font", arg: f, label: f }) })
        icons.forEach(function (e) { if (starter.icons.indexOf(e.id) >= 0 && !e.installed) miss.push({ kind: "icon", arg: e.id, label: e.name + " icons" }) })
        cursors.forEach(function (e) { if (starter.cursors.indexOf(e.id) >= 0 && !e.installed) miss.push({ kind: "cursor", arg: e.id, label: e.name + " cursor" }) })
        return miss
    }
    function installStarter() { starterMissing().forEach(enqueue) }
    function cancelQueue() {
        var p = {}
        if (current) p[key(current.kind, current.arg)] = true
        pendingKeys = p
        totalCount = doneCount + (current ? 1 : 0)
        queue = []
    }

    function next() {
        if (busy || queue.length === 0) return
        var job = queue[0]
        queue = queue.slice(1)
        current = job
        message = ""
        var cmd = ["python3", script]
        if (job.kind === "font") cmd = cmd.concat(["install-font", job.arg])
        else if (job.kind === "icon") cmd = cmd.concat(["install-icon", job.arg])
        else if (job.kind === "cursor") cmd = cmd.concat(["install-cursor", job.arg])
        else if (job.kind === "path") cmd = cmd.concat(["install-path", job.arg])
        else cmd = cmd.concat(["remove", job.kind2, job.name])
        jobProc.command = cmd
        jobProc.running = true
    }
    Component { id: fontLoaderComp; FontLoader {} }
    property var fontLoaders: []
    function loadFontFiles(files) {
        var l = fontLoaders.slice()
        ;(files || []).forEach(function (f) { l.push(fontLoaderComp.createObject(lib, { source: "file://" + f })) })
        fontLoaders = l
        fontRefreshT.restart()
    }
    Timer { id: fontRefreshT; interval: 400; onTriggered: Theme.refreshFonts() }
    Process {
        id: jobProc
        stdout: StdioCollector { id: jobOut }
        onExited: code => {
            var job = lib.current, o = {}
            try { o = JSON.parse(jobOut.text) } catch (e) { o = { ok: false, error: "asset-store.py failed (exit " + code + ")" } }
            if (o.ok) {
                if (job.kind === "font") {
                    lib.loadFontFiles(o.files)
                    lib.fonts = lib.fonts.map(function (x) { return x.f === o.family ? Object.assign({}, x, { i: true }) : x })
                    lib.message = o.family + " installed"
                } else if (job.kind === "path") {
                    lib.loadFontFiles(o.files)
                    var got = [].concat(o.fonts || [], o.icons || [], o.cursors || [])
                    lib.message = "Added " + got.join(", ")
                } else if (job.kind === "remove") {
                    lib.message = "Removed " + job.name
                    if (job.kind2 === "font") fontRefreshT.restart()
                } else {
                    var list = job.kind === "icon" ? lib.icons : lib.cursors
                    list = list.map(function (x) { return x.id === o.id ? Object.assign({}, x, { installed: true, themes: o.themes }) : x })
                    if (job.kind === "icon") lib.icons = list; else lib.cursors = list
                    lib.message = job.label + " installed: " + (o.themes || []).join(", ")
                }
                lib.messageError = false
            } else {
                lib.failures = lib.failures.concat([job.label + ": " + (o.error || "failed")])
                lib.message = job.label + ": " + (o.error || "failed")
                lib.messageError = true
            }
            var p = Object.assign({}, lib.pendingKeys); delete p[lib.key(job.kind, job.arg)]; lib.pendingKeys = p
            lib.doneCount += 1
            lib.current = null
            if (lib.queue.length > 0) {
                if (job.kind !== "font") Settings.listDesktop()
                lib.next()
            } else {
                if (lib.totalCount > 1) {
                    lib.message = "Finished " + (lib.totalCount - lib.failures.length) + " of " + lib.totalCount
                        + (lib.failures.length ? ". Failed: " + lib.failures.join("; ") : "")
                    lib.messageError = lib.failures.length > 0
                }
                Settings.listDesktop()
                lib.load(false)
            }
        }
    }

    // ---- previews of fonts that are not installed (PNG with the family name drawn in its own face)
    property var previews: ({})       // "color|family" -> png path ("" when it failed)
    property var previewWanted: []
    property string previewColor: "#e6e6f0"
    function preview(family) { return previews[previewColor + "|" + family] }
    function requestPreviews(families, color) {
        previewColor = color
        var want = previewWanted.slice()
        families.forEach(function (f) { if (lib.preview(f) === undefined && want.indexOf(f) < 0) want.push(f) })
        previewWanted = want
        nextPreview()
    }
    function nextPreview() {
        if (previewProc.running || previewWanted.length === 0) return
        var batch = previewWanted.slice(0, 16)
        previewWanted = previewWanted.slice(16)
        previewProc.batch = batch
        previewProc.color = previewColor
        previewProc.command = ["python3", script, "preview-fonts", previewColor].concat(batch)
        previewProc.running = true
    }
    Process {
        id: previewProc
        property var batch: []
        property string color: ""
        stdout: StdioCollector { id: previewOut }
        onExited: code => {
            var res = {}
            try { res = JSON.parse(previewOut.text).previews || {} } catch (e) {}
            var p = Object.assign({}, lib.previews)
            previewProc.batch.forEach(function (f) { p[previewProc.color + "|" + f] = res[f] || "" })
            lib.previews = p
            lib.nextPreview()
        }
    }

    // ---- apply helpers
    function openFolder(path) { Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && xdg-open \"$1\"", "_", path]) }

    // quickshell ipc call styles installFont "Caveat" | styles installStarter | styles status
    IpcHandler {
        target: "styles"
        function installFont(family: string): void { lib.installFont(family) }
        function installIcon(id: string): void { lib.enqueue({ kind: "icon", arg: id, label: id + " icons" }) }
        function installCursor(id: string): void { lib.enqueue({ kind: "cursor", arg: id, label: id + " cursor" }) }
        function installPath(path: string): void { lib.installPath(path) }
        function installStarter(): void { if (lib.loaded) lib.installStarter(); else { starterAfterLoad.enabled = true; lib.load(false) } }
        function status(): string {
            return JSON.stringify({ busy: lib.busy, current: lib.current ? lib.current.label : "", done: lib.doneCount, total: lib.totalCount,
                                    queued: lib.queue.length, message: lib.message, failures: lib.failures })
        }
    }
    Connections {
        id: starterAfterLoad
        enabled: false
        target: lib
        function onLoadedChanged() { if (lib.loaded) { starterAfterLoad.enabled = false; lib.installStarter() } }
    }
}
