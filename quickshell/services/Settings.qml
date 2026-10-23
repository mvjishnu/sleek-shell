pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// =============================================================================
//  Settings — Sleek Shell behaviour (not appearance; that is Theme.qml).
//  Owns ~/.config/sleek-shell/settings.json. Values are validated on load and on every set();
//  invalid or missing values fall back to the defaults below.
// =============================================================================
Singleton {
    id: st

    readonly property string home: Quickshell.env("HOME")
    readonly property string path: home + "/.config/sleek-shell/settings.json"

    // Every bar widget, in its default order. "left" / "right" say which side it lives on.
    readonly property var widgetCatalog: ({
        notifications: { name: "Notifications", side: "left" },
        clipboard:     { name: "Clipboard", side: "left" },
        workspaces:    { name: "Workspaces", side: "left" },
        mic:           { name: "Microphone muted indicator", side: "right" },
        media:         { name: "Media player", side: "right" },
        appearance:    { name: "Appearance", side: "right" },
        volume:        { name: "Volume", side: "right" },
        wifi:          { name: "Wi-Fi", side: "right" },
        bluetooth:     { name: "Bluetooth", side: "right" },
        battery:       { name: "Battery & brightness", side: "right" },
        power:         { name: "Power", side: "left" }
    })

    readonly property var defaults: ({
        barDensity: "compact", barIconStyle: "color",
        leftOrder: ["power", "notifications", "clipboard", "workspaces"],
        rightOrder: ["mic", "media", "appearance", "volume", "wifi", "bluetooth", "battery"],
        hidden: [],
        clock24h: false, clockSeconds: false, clockDate: true,
        workspaceStyle: "dots",
        dnd: false, toastTimeout: 6, toastMax: 3, historyMax: 80,
        osd: true, islandMedia: true,
        wallpaperDir: "~/Pictures/Wallpapers", wallpaperTransition: "wave",
        lockAvatar: true, lockShowMedia: true, lockShowNotifications: true, avatarStamp: 0,
        idleLockMin: 10, idleScreenOffMin: 15, idleSuspendMin: 0, idleRespectInhibitors: true, lockBeforeSleep: true,
        appFont: "Noto Sans", appFontSize: 10, monoFont: "JetBrainsMono Nerd Font", monoFontSize: 11,
        iconTheme: "Papirus-Dark", cursorTheme: "Adwaita", cursorSize: 24
    })

    property string barDensity: "compact"
    property string barIconStyle: "color"
    property var    leftOrder: defaults.leftOrder
    property var    rightOrder: defaults.rightOrder
    property var    hidden: []
    property bool   clock24h: false
    property bool   clockSeconds: false
    property bool   clockDate: true
    property string workspaceStyle: "dots"
    property bool   dnd: false
    property int    toastTimeout: 6
    property int    toastMax: 3
    property int    historyMax: 80
    property bool   osd: true
    property bool   islandMedia: true
    property string wallpaperDir: "~/Pictures/Wallpapers"
    property string wallpaperTransition: "wave"
    property bool   lockAvatar: true            // show the profile picture on the lock screen
    property bool   lockShowMedia: true
    property bool   lockShowNotifications: true
    property int    avatarStamp: 0              // bumped when the picture changes (reloads cached images)
    // idle (ext-idle-notify via modules/lock/IdleGuard.qml); minutes, 0 = never
    property int    idleLockMin: 10
    property int    idleScreenOffMin: 15
    property int    idleSuspendMin: 0
    property bool   idleRespectInhibitors: true
    property bool   lockBeforeSleep: true
    readonly property var idleLockChoices: [0, 1, 2, 5, 10, 15, 30]
    readonly property var idleScreenChoices: [0, 1, 2, 5, 10, 15, 30]
    readonly property var idleSuspendChoices: [0, 15, 30, 60, 120]
    // desktop-wide (GTK / Qt / fontconfig / kitty / Rofi), applied by scripts/desktop-prefs.py
    property string appFont: "Noto Sans"
    property int    appFontSize: 10
    property string monoFont: "JetBrainsMono Nerd Font"
    property int    monoFontSize: 11
    property string iconTheme: "Papirus-Dark"
    property string cursorTheme: "Adwaita"
    property int    cursorSize: 24
    readonly property var cursorSizes: [16, 24, 32, 48, 64]
    // calculator prefs live under "calc" in the same file; the calculator writes angleMode itself
    property var    calc: ({ angleMode: "deg", precision: 12 })
    property bool   calcDirty: false
    readonly property string avatarPath: home + "/.config/sleek-shell/avatar"
    property bool   loaded: false

    readonly property string wallpaperPath: wallpaperDir.replace(/^~(?=\/|$)/, home)
    readonly property var transitions: ["wave", "grow", "outer", "wipe", "fade", "simple", "any", "random"]

    function shown(id) { return hidden.indexOf(id) < 0 }

    function orderList(v, side) {
        var out = [], seen = {}
        if (Array.isArray(v)) v.forEach(function (id) {
            if (widgetCatalog[id] && widgetCatalog[id].side === side && !seen[id]) { seen[id] = 1; out.push(id) }
        })
        // widgets added (or moved to this side) in a newer version go to their default position
        var def = side === "left" ? defaults.leftOrder : defaults.rightOrder
        def.forEach(function (id, i) { if (!seen[id]) { seen[id] = 1; out.splice(Math.min(i, out.length), 0, id) } })
        return out
    }
    function sanitize(k, v) {
        var d = defaults[k]
        switch (k) {
        case "barDensity": return v === "comfortable" ? "comfortable" : "compact"
        case "barIconStyle": return v === "mono" ? "mono" : "color"
        case "leftOrder": return orderList(v, "left")
        case "rightOrder": return orderList(v, "right")
        case "hidden": return Array.isArray(v) ? v.filter(function (id) { return !!widgetCatalog[id] }) : []
        case "workspaceStyle": return ["dots", "numbers"].indexOf(v) >= 0 ? v : d
        case "toastTimeout": return Math.max(2, Math.min(30, Math.round(Number(v) || d)))
        case "toastMax": return Math.max(1, Math.min(6, Math.round(Number(v) || d)))
        case "historyMax": return Math.max(10, Math.min(300, Math.round(Number(v) || d)))
        case "wallpaperDir": return typeof v === "string" && v.length > 0 && v.length < 300 ? v : d
        case "wallpaperTransition": return transitions.indexOf(v) >= 0 ? v : d
        case "avatarStamp": return Math.max(0, Math.round(Number(v) || 0))
        case "idleLockMin": return idleLockChoices.indexOf(Number(v)) >= 0 ? Number(v) : d
        case "idleScreenOffMin": return idleScreenChoices.indexOf(Number(v)) >= 0 ? Number(v) : d
        case "idleSuspendMin": return idleSuspendChoices.indexOf(Number(v)) >= 0 ? Number(v) : d
        case "appFont": case "monoFont": case "iconTheme": case "cursorTheme":
            return typeof v === "string" && v.length > 0 && v.length < 120 && !/[\n\r"]/.test(v) ? v : d
        case "appFontSize": return Math.max(7, Math.min(24, Math.round(Number(v) || d)))
        case "monoFontSize": return Math.max(7, Math.min(28, Math.round(Number(v) || d)))
        case "cursorSize": return Math.max(16, Math.min(64, Math.round(Number(v) || d)))
        default: return typeof v === typeof d ? v : d
        }
    }
    function set(k, v) {
        if (!(k in defaults)) return
        st[k] = sanitize(k, v)
        saveTimer.restart()
    }
    function toggleHidden(id) {
        var h = hidden.slice(), i = h.indexOf(id)
        if (i >= 0) h.splice(i, 1); else h.push(id)
        set("hidden", h)
    }
    function move(id, delta) {
        var side = widgetCatalog[id].side, key = side === "left" ? "leftOrder" : "rightOrder"
        var l = st[key].slice(), i = l.indexOf(id), j = i + delta
        if (i < 0 || j < 0 || j >= l.length) return
        l.splice(i, 1); l.splice(j, 0, id)
        set(key, l)
    }
    // ---- profile picture: a private copy in ~/.config/sleek-shell/avatar (the original is never touched)
    readonly property var imageExts: ["png", "jpg", "jpeg", "webp", "gif", "bmp"]
    property string avatarMsg: ""
    property bool hasAvatar: false
    Process { id: avatarProbe; command: ["test", "-f", st.avatarPath]; onExited: code => st.hasAvatar = code === 0 }
    function checkAvatar() { if (!avatarProbe.running) avatarProbe.running = true }
    function setAvatar(file) {
        var f = String(file || "").trim().replace(/^file:\/\//, "").replace(/^~(?=\/|$)/, home)
        var ext = (f.split(".").pop() || "").toLowerCase()
        if (f === "" || imageExts.indexOf(ext) < 0) { avatarMsg = "Choose a .png, .jpg, .webp, .gif or .bmp image"; return }
        avatarCopy.clearing = false
        avatarCopy.command = ["sh", "-c", "[ -f \"$1\" ] || exit 3; mkdir -p \"$(dirname \"$2\")\" && cp -f -- \"$1\" \"$2\"", "_", f, avatarPath]
        avatarCopy.running = true
    }
    function clearAvatar() { hasAvatar = false; avatarCopy.clearing = true; avatarCopy.command = ["rm", "-f", avatarPath]; avatarCopy.running = true }
    Process {
        id: avatarCopy
        property bool clearing: false
        onExited: code => {
            st.avatarMsg = code === 0 ? "" : (code === 3 ? "That file does not exist" : "Could not save the picture")
            if (code === 0) st.hasAvatar = !clearing        // known before the image re-loads: no request for a missing file
            st.set("avatarStamp", st.avatarStamp + 1)
            st.checkAvatar()
        }
    }

    function sanitizeCalc(c) {
        c = c && typeof c === "object" && !Array.isArray(c) ? c : {}
        var p = Number(c.precision)
        return { angleMode: c.angleMode === "rad" ? "rad" : "deg",
                 precision: isFinite(p) && typeof c.precision !== "boolean" ? Math.max(1, Math.min(40, Math.round(p))) : 12 }
    }
    function setCalc(k, v) {
        var c = Object.assign({}, calc); c[k] = v
        calc = sanitizeCalc(c); calcDirty = true
        saveTimer.restart()
    }
    function readDisk() {
        store.reload(); store.waitForJob()
        try { var t = store.text(); if (t && t.trim() !== "") { var o = JSON.parse(t); if (o && typeof o === "object" && !Array.isArray(o)) return o } } catch (e) {}
        return {}
    }
    function refreshCalc() { if (!calcDirty) calc = sanitizeCalc(readDisk().calc) }

    // ---- system fonts + icon theme
    property var desktopInfo: ({ ui: [], mono: [], icons: [], cursors: [], library: [], current: {} })
    property bool desktopListing: false
    property string desktopMsg: ""
    property bool desktopApplying: false
    readonly property string desktopScript: Quickshell.shellDir + "/scripts/desktop-prefs.py"
    function listDesktop() { if (!desktopList.running) { desktopListing = true; desktopList.running = true } }
    function setDesktop(k, v) { set(k, v); desktopApplyT.restart() }
    function applyDesktop() {
        if (desktopApply.running) { desktopApplyT.restart(); return }
        desktopApplying = true
        desktopApply.command = ["python3", desktopScript, "apply", appFont, String(appFontSize), monoFont, String(monoFontSize), iconTheme, cursorTheme, String(cursorSize)]
        desktopApply.running = true
    }
    Timer { id: desktopApplyT; interval: 450; onTriggered: st.applyDesktop() }
    Process {
        id: desktopList
        command: ["python3", st.desktopScript, "list"]
        stdout: StdioCollector { id: desktopListOut }
        onExited: code => {
            st.desktopListing = false
            try { var o = JSON.parse(desktopListOut.text); if (o.ok) st.desktopInfo = o } catch (e) { st.desktopMsg = "Could not list fonts and icon themes" }
        }
    }
    Process {
        id: desktopApply
        stdout: StdioCollector { id: desktopApplyOut }
        onExited: code => {
            st.desktopApplying = false
            var o = {}
            try { o = JSON.parse(desktopApplyOut.text) } catch (e) { o = { ok: false, error: "desktop-prefs.py failed (exit " + code + ")" } }
            if (o.error) st.desktopMsg = o.error
            else if (o.errors && o.errors.length) st.desktopMsg = "Partly applied: " + o.errors.join("; ")
            else st.desktopMsg = o.changed && o.changed.length ? "Applied to GTK, Qt, fontconfig, kitty, Rofi and the cursor. Already-open apps may need a restart." : "Already up to date"
            st.listDesktop()
        }
    }

    function resetDefaults() {
        for (var k in defaults) st[k] = sanitize(k, defaults[k])
        saveTimer.restart()
    }

    // quickshell ipc call prefs set barDensity comfortable | prefs set clock24h true | prefs get
    IpcHandler {
        target: "prefs"
        function set(key: string, value: string): void {
            var v = value
            try { v = JSON.parse(value) } catch (e) {}
            st.set(key, v)
        }
        function get(): string { var o = {}; for (var k in st.defaults) o[k] = st[k]; return JSON.stringify(o) }
        function reset(): void { st.resetDefaults() }
        function setAvatar(path: string): void { st.setAvatar(path) }
        function clearAvatar(): void { st.clearAvatar() }
        function applyDesktop(): void { st.applyDesktop() }
        function setCalc(key: string, value: string): void { var v = value; try { v = JSON.parse(value) } catch (e) {} st.setCalc(key, v) }
        function getCalc(): string { st.refreshCalc(); return JSON.stringify(st.calc) }
    }

    FileView { id: store; path: st.path; blockLoading: true; printErrors: false; atomicWrites: true }
    Timer {
        id: saveTimer; interval: 300
        onTriggered: {
            // merge into what is on disk so keys owned by other tools (calc.angleMode, future keys) survive
            var disk = st.readDisk(), o = {}
            for (var x in disk) o[x] = disk[x]
            o.version = 1
            for (var k in st.defaults) o[k] = st[k]
            if (st.calcDirty) {
                var c = disk.calc && typeof disk.calc === "object" && !Array.isArray(disk.calc) ? Object.assign({}, disk.calc) : {}
                c.angleMode = st.calc.angleMode; c.precision = st.calc.precision
                o.calc = c; st.calcDirty = false
            } else if (disk.calc !== undefined) st.calc = st.sanitizeCalc(disk.calc)
            store.setText(JSON.stringify(o, null, 2) + "\n")
        }
    }
    Component.onCompleted: {
        var raw = {}
        try { var t = store.text(); if (t && t.trim() !== "") raw = JSON.parse(t) } catch (e) { raw = {} }
        for (var k in defaults) st[k] = sanitize(k, k in raw ? raw[k] : defaults[k])
        calc = sanitizeCalc(raw.calc)
        loaded = true
        checkAvatar()
        if (!raw.version) saveTimer.restart()
    }
}
