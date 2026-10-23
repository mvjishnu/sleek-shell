pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// =============================================================================
//  Theme — the Sleek Shell design system and theme engine. One source of truth.
//
//  Owns  ~/.config/sleek-shell/appearance.json   (current appearance, validated on load)
//        ~/.config/sleek-shell/themes.json       (user-created themes)
//        ~/.config/sleek-shell/hypr-look.lua     (generated for hypr/sleekshell/look.lua)
//  Pushes colours to kitty / rofi / GTK / KDE / micro through scripts/apply-theme.sh and the
//  light/dark flag through scripts/apply-mode.sh.
//
//  Every component reads tokens from here (colours, radii, strokes, shadows, spacing, type,
//  motion). Nothing else writes these files.
// =============================================================================
Singleton {
    id: theme

    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: home + "/.config/sleek-shell"

    // ---- built-in palettes: tint is the glass base, accent the highlight ----
    readonly property var palettes: [
        { id: "navy",     name: "Navy",     tint: [42, 38, 82],    accent: [124, 156, 255], text: "#f4f1ff", muted: "#a9a6cc" },
        { id: "graphite", name: "Graphite", tint: [46, 46, 54],    accent: [150, 162, 184], text: "#f2f2f7", muted: "#a8a8b4" },
        { id: "violet",   name: "Violet",   tint: [58, 40, 96],    accent: [176, 140, 255], text: "#f6f1ff", muted: "#b3a6d6" },
        { id: "rose",     name: "Rose",     tint: [78, 34, 58],    accent: [255, 130, 180], text: "#fff1f6", muted: "#d6a6bb" },
        { id: "forest",   name: "Forest",   tint: [26, 60, 48],    accent: [110, 220, 170], text: "#f0fff8", muted: "#9fcbb9" },
        { id: "ocean",    name: "Ocean",    tint: [24, 56, 82],    accent: [104, 190, 255], text: "#f0f8ff", muted: "#9fc0d8" },
        { id: "ember",    name: "Ember",    tint: [70, 40, 24],    accent: [255, 168, 96],  text: "#fff4ec", muted: "#d6b199" },
        { id: "mocha",    name: "Mocha",    tint: [54, 46, 42],    accent: [214, 172, 136], text: "#f5efe8", muted: "#c4b3a4" },
        { id: "nord",     name: "Nord",     tint: [40, 48, 60],    accent: [136, 192, 208], text: "#eceff4", muted: "#a3adba" },
        { id: "tokyo",    name: "Tokyo",    tint: [32, 34, 52],    accent: [122, 162, 247], text: "#eef0ff", muted: "#a0a4c8" },
        { id: "sakura",   name: "Sakura",   tint: [64, 40, 56],    accent: [255, 155, 200], text: "#fff2f8", muted: "#d4a8c0" },
        { id: "matcha",   name: "Matcha",   tint: [40, 56, 38],    accent: [168, 220, 130], text: "#f3fff0", muted: "#b6cfab" }
    ]
    readonly property var accentSwatches: [[139, 224, 255], [182, 154, 255], [255, 112, 197], [165, 245, 139], [255, 228, 94], [255, 107, 134], [255, 168, 96]]

    // ---- defaults (also the reset target and the recovery values) ----
    readonly property var defaults: ({
        palette: "navy", accent: "", glass: 0.62,
        blurSize: 8, blurPasses: 3, blurBrightness: 100,
        mode: "dark", styleMode: "glass",
        colorfulBorders: true, borderWidth: 2,
        shellBorders: true, shadows: true, radiusScale: 1.0, fontFamily: "",
        windowRounding: 14, gapsIn: 3, gapsOut: 6, activeOpacity: 0.88, inactiveOpacity: 0.78, windowShadows: false,
        animations: true, animSpeed: 1.0,
        activeTheme: ""
    })
    readonly property var themeKeys: ["palette", "accent", "glass", "blurSize", "blurPasses", "blurBrightness", "mode", "styleMode",
        "colorfulBorders", "borderWidth", "shellBorders", "shadows", "radiusScale", "fontFamily",
        "windowRounding", "gapsIn", "gapsOut", "activeOpacity", "inactiveOpacity", "windowShadows", "animations", "animSpeed"]

    // ---- current values (persisted). Change them only through set()/apply functions ----
    property string paletteId: "navy"
    property string accentOverride: ""
    property real   glassOpacity: 0.62
    property int    blurSize: 8
    property int    blurPasses: 3
    property int    blurBrightness: 100
    property string mode: "dark"
    property string styleMode: "glass"
    property bool   colorfulBorders: true
    property int    borderWidth: 2
    property bool   shellBorders: true
    property bool   shadows: true
    property real   radiusScale: 1.0
    property string fontFamily: ""
    property int    windowRounding: 14
    property int    gapsIn: 3
    property int    gapsOut: 6
    property real   activeOpacity: 0.88
    property real   inactiveOpacity: 0.78
    property bool   windowShadows: false
    property bool   animations: true
    property real   animSpeed: 1.0
    property string activeTheme: ""

    property var    userThemes: []          // [{ name, created, values }]
    property bool   loaded: false
    property string compositorStatus: "Not applied"
    property string lastMessage: ""
    readonly property bool darkMode: mode !== "light"
    readonly property bool light: mode === "light"

    function findPalette(id) {
        for (var i = 0; i < palettes.length; ++i) if (palettes[i].id === id) return palettes[i]
        return palettes[0]
    }
    readonly property var palette: findPalette(paletteId)

    // =========================================================================
    //  validation
    // =========================================================================
    function clamp(v, lo, hi, d) { v = Number(v); if (isNaN(v)) return d; return Math.max(lo, Math.min(hi, v)) }
    function validHex(s) { return typeof s === "string" && /^#?[0-9a-fA-F]{6}$/.test(s) }
    function normHex(s) { return validHex(s) ? ("#" + s.replace("#", "")).toLowerCase() : "" }

    function sanitize(k, v) {
        var d = defaults[k]
        switch (k) {
        case "palette": return palettes.some(function (p) { return p.id === v }) ? v : d
        case "accent": return normHex(v)
        case "glass": return clamp(v, 0.15, 1, d)
        case "blurSize": return Math.round(clamp(v, 1, 24, d))
        case "blurPasses": return Math.round(clamp(v, 1, 6, d))
        case "blurBrightness": return Math.round(clamp(v, 60, 160, d))
        case "mode": return v === "light" ? "light" : "dark"
        case "styleMode": return v === "solid" ? "solid" : "glass"
        case "borderWidth": return Math.round(clamp(v, 0, 4, d))
        case "radiusScale": return clamp(v, 0.4, 1.6, d)
        case "fontFamily": return typeof v === "string" && v.length < 80 ? v : ""
        case "windowRounding": return Math.round(clamp(v, 0, 30, d))
        case "gapsIn": return Math.round(clamp(v, 0, 30, d))
        case "gapsOut": return Math.round(clamp(v, 0, 60, d))
        case "activeOpacity": return clamp(v, 0.3, 1, d)
        case "inactiveOpacity": return clamp(v, 0.3, 1, d)
        case "animSpeed": return clamp(v, 0.25, 3, d)
        case "activeTheme": return typeof v === "string" ? v.slice(0, 48) : ""
        case "colorfulBorders": case "shellBorders": case "shadows": case "windowShadows": case "animations":
            return typeof v === "boolean" ? v : d
        }
        return d
    }

    readonly property var propOf: ({
        palette: "paletteId", accent: "accentOverride", glass: "glassOpacity", blurSize: "blurSize", blurPasses: "blurPasses",
        blurBrightness: "blurBrightness", mode: "mode", styleMode: "styleMode", colorfulBorders: "colorfulBorders",
        borderWidth: "borderWidth", shellBorders: "shellBorders", shadows: "shadows", radiusScale: "radiusScale",
        fontFamily: "fontFamily", windowRounding: "windowRounding", gapsIn: "gapsIn", gapsOut: "gapsOut",
        activeOpacity: "activeOpacity", inactiveOpacity: "inactiveOpacity", windowShadows: "windowShadows",
        animations: "animations", animSpeed: "animSpeed", activeTheme: "activeTheme"
    })
    readonly property var hyprKeys: ["palette", "accent", "styleMode", "blurSize", "blurPasses", "blurBrightness", "colorfulBorders",
        "borderWidth", "windowRounding", "gapsIn", "gapsOut", "activeOpacity", "inactiveOpacity", "windowShadows", "animations", "animSpeed"]
    readonly property var exportKeys: ["palette", "accent", "glass", "blurSize", "mode", "styleMode"]

    function get(k) { return theme[propOf[k]] }
    function snapshot() {
        var o = {}
        for (var i = 0; i < themeKeys.length; ++i) o[themeKeys[i]] = get(themeKeys[i])
        return o
    }

    // The one way to change appearance. Validates, applies, persists, syncs compositor + apps.
    function set(k, v) {
        if (!(k in propOf)) return
        var s = sanitize(k, v)
        if (get(k) === s) return
        theme[propOf[k]] = s
        if (k === "palette") accentOverride = ""
        if (k === "mode") applyMode()
        afterChange([k])
    }
    function setMany(obj) {
        var changed = []
        for (var k in obj) {
            if (!(k in propOf)) continue
            var s = sanitize(k, obj[k])
            if (get(k) !== s) { theme[propOf[k]] = s; changed.push(k) }
        }
        if (changed.indexOf("mode") >= 0) applyMode()
        afterChange(changed)
    }
    function afterChange(keys) {
        if (!keys.length || !loaded) return
        saveTimer.restart()
        var hy = false, ex = false
        for (var i = 0; i < keys.length; ++i) {
            if (hyprKeys.indexOf(keys[i]) >= 0) hy = true
            if (exportKeys.indexOf(keys[i]) >= 0) ex = true
        }
        if (hy) applyHypr()
        if (ex) exportTimer.restart()
    }

    // Back-compatible setters used by existing components.
    function setPalette(id)       { set("palette", id); activeTheme = "" }
    function setAccent(hex)       { set("accent", hex) }
    function setGlassOpacity(v)   { set("glass", v) }
    function setBlurSize(v)       { set("blurSize", v) }
    function setBlurPasses(v)     { set("blurPasses", v) }
    function setBlurBrightness(v) { set("blurBrightness", v) }
    function setStyleMode(v)      { set("styleMode", v) }
    function setColorfulBorders(v){ set("colorfulBorders", !!v) }
    function setBorderWidth(v)    { set("borderWidth", v) }
    function setMode(m)           { set("mode", m) }
    function touch()              { saveTimer.restart(); exportTimer.restart() }

    // ---- user themes ----
    function themeIndex(name) {
        for (var i = 0; i < userThemes.length; ++i) if (userThemes[i].name.toLowerCase() === String(name).toLowerCase()) return i
        return -1
    }
    function cleanName(n) { return String(n || "").replace(/[^\w \-.()]/g, "").trim().slice(0, 40) }
    function saveTheme(name) {
        var n = cleanName(name)
        if (n === "") { lastMessage = "Give the theme a name first"; return false }
        var list = userThemes.slice(), i = themeIndex(n), entry = { name: n, created: Date.now(), values: snapshot() }
        if (i >= 0) list[i] = entry; else list.push(entry)
        userThemes = list
        activeTheme = n
        writeThemes(); saveTimer.restart()
        lastMessage = (i >= 0 ? "Updated theme “" : "Saved theme “") + n + "”"
        return true
    }
    function applyValues(values, name) {
        var o = {}
        for (var i = 0; i < themeKeys.length; ++i) {
            var k = themeKeys[i]
            o[k] = values && (k in values) ? values[k] : defaults[k]
        }
        o.activeTheme = name || ""
        setMany(o)
        activeTheme = name || ""
    }
    function applyTheme(name) {
        var i = themeIndex(name)
        if (i < 0) return
        applyValues(userThemes[i].values, userThemes[i].name)
        lastMessage = "Applied “" + userThemes[i].name + "”"
    }
    function deleteTheme(name) {
        var i = themeIndex(name)
        if (i < 0) return
        var list = userThemes.slice(); list.splice(i, 1); userThemes = list
        if (activeTheme === name) activeTheme = ""
        writeThemes()
        lastMessage = "Deleted “" + name + "”"
    }
    function renameTheme(oldName, newName) {
        var i = themeIndex(oldName), n = cleanName(newName)
        if (i < 0 || n === "" || (themeIndex(n) >= 0 && themeIndex(n) !== i)) { lastMessage = "That name is empty or already used"; return }
        var list = userThemes.slice(); list[i] = { name: n, created: list[i].created, values: list[i].values }; userThemes = list
        if (activeTheme === oldName) activeTheme = n
        writeThemes()
    }
    function resetDefaults() {
        applyValues(defaults, "")
        lastMessage = "Appearance reset to Sleek Shell defaults"
    }
    // Export writes one theme file into ~/Downloads (created if needed); returns the path.
    function exportTheme(name) {
        var i = themeIndex(name)
        var payload = { sleekShellTheme: 1, name: i >= 0 ? userThemes[i].name : (cleanName(name) || "Current"), values: i >= 0 ? userThemes[i].values : snapshot() }
        var file = home + "/Downloads/sleek-shell-theme-" + payload.name.replace(/\s+/g, "-").toLowerCase() + ".json"
        exporter.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"", "_", file, JSON.stringify(payload, null, 2)]
        exporter.running = true
        lastMessage = "Exported to " + file.replace(home, "~")
        return file
    }
    function importTheme(path) {
        var p = String(path || "").trim().replace(/^~(?=\/|$)/, home)
        if (p === "") { lastMessage = "Enter the path of a theme file"; return }
        importer.command = ["cat", "--", p]
        importer.running = true
    }
    function acceptImport(text) {
        var o
        try { o = JSON.parse(text) } catch (e) { lastMessage = "Not a valid theme file (JSON error)"; return }
        if (!o || (o.sleekShellTheme !== 1 && o.sleakShellTheme !== 1 && o.sleakosTheme !== 1) || typeof o.values !== "object") { lastMessage = "Not a Sleek Shell theme file"; return }
        var values = {}
        for (var i = 0; i < themeKeys.length; ++i) { var k = themeKeys[i]; values[k] = sanitize(k, k in o.values ? o.values[k] : defaults[k]) }
        var n = cleanName(o.name) || "Imported", base = n, c = 2
        while (themeIndex(n) >= 0) n = base + " " + (c++)
        var list = userThemes.slice(); list.push({ name: n, created: Date.now(), values: values }); userThemes = list
        writeThemes()
        lastMessage = "Imported “" + n + "”. Select it to apply."
    }
    // quickshell ipc call theme set mode light | theme set glass 0.4 | theme apply "Midnight" | theme get
    IpcHandler {
        target: "theme"
        function set(key: string, value: string): void {
            var v = value === "true" ? true : value === "false" ? false : (value !== "" && !isNaN(Number(value)) && key !== "accent" ? Number(value) : value)
            theme.set(key, v)
        }
        function apply(name: string): void { theme.applyTheme(name) }
        function save(name: string): void { theme.saveTheme(name) }
        function reset(): void { theme.resetDefaults() }
        function get(): string { var o = theme.snapshot(); o.activeTheme = theme.activeTheme; return JSON.stringify(o) }
        function toggleMode(): void { theme.set("mode", theme.light ? "dark" : "light") }
        // theme appScope selected | theme app kitty off | theme appCustom gtk rose "#ff00aa" | theme apps
        function appScope(scope: string): void { theme.setAppScope(scope) }
        function app(id: string, mode: string): void { theme.setAppRule(id, { mode: mode }) }
        function appCustom(id: string, palette: string, accent: string): void { theme.setAppRule(id, { mode: "custom", palette: palette, accent: accent }) }
        function appsReset(): void { theme.resetApps() }
        function apps(): string {
            var o = { scope: theme.appScope, apps: {} }
            theme.themedApps.forEach(function (a) { o.apps[a.id] = theme.appRule(a.id); o.apps[a.id].mode = theme.appMode(a.id) })
            return JSON.stringify(o)
        }
    }
    Process { id: exporter; onExited: code => { if (code !== 0) theme.lastMessage = "Export failed" } }
    Process {
        id: importer
        stdout: StdioCollector { onStreamFinished: if (text !== "") theme.acceptImport(text) }
        onExited: code => { if (code !== 0) theme.lastMessage = "Could not read that file" }
    }

    // =========================================================================
    //  colour engine
    // =========================================================================
    function rgb(a) { return Qt.rgba(a[0] / 255, a[1] / 255, a[2] / 255, 1) }
    function hex(a) {
        function h(n) { var s = Math.round(Math.max(0, Math.min(255, n))).toString(16); return s.length < 2 ? "0" + s : s }
        return h(a[0]) + h(a[1]) + h(a[2])
    }
    function mixA(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t] }
    function lerp(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t) }
    function luminance(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

    // In light mode the tint is washed out to paper; glass gets a little more body for dark text.
    readonly property var baseTint: light ? mixA(palette.tint, [255, 255, 255], 0.86) : palette.tint
    readonly property real op: light ? 0.38 + 0.62 * glassOpacity : glassOpacity
    function glass(alpha, white) {
        var c = baseTint, w = light ? white * 0.6 : white
        return Qt.rgba((c[0] + (255 - c[0]) * w) / 255, (c[1] + (255 - c[1]) * w) / 255,
                       (c[2] + (255 - c[2]) * w) / 255, styleMode === "solid" ? 1 : Math.min(1, alpha))
    }
    readonly property real whiteMix: 0.04 + 0.16 * op

    // light pills need body to stay readable over dark wallpapers (they read as grey otherwise)
    readonly property color glassBarTop:     light ? glass(0.72 + 0.24 * glassOpacity, whiteMix) : glass(0.06 + 0.72 * op, whiteMix)
    readonly property color glassBarBottom:  light ? glass(0.76 + 0.22 * glassOpacity, whiteMix * 0.5) : glass(0.10 + 0.68 * op, whiteMix * 0.5)
    readonly property color glassPopTop:     glass(0.22 + 0.66 * op, whiteMix)
    readonly property color glassPopBottom:  glass(0.26 + 0.64 * op, whiteMix * 0.5)
    readonly property color glassCritTop:    light ? Qt.rgba(1, 0.86, 0.89, 0.6 + 0.35 * op) : Qt.rgba(0.325, 0.165, 0.345, 0.42 + 0.44 * op)
    readonly property color glassCritBottom: light ? Qt.rgba(1, 0.80, 0.84, 0.6 + 0.35 * op) : Qt.rgba(0.165, 0.070, 0.188, 0.38 + 0.44 * op)

    readonly property color ink: light ? "#000000" : "#ffffff"
    readonly property color surface: styleMode === "solid" ? glass(1, light ? 0.5 : 0.04) : Qt.alpha(ink, (light ? 0.05 : 0.06) + 0.07 * (1 - op))
    readonly property color surfaceHi: styleMode === "solid" ? glass(1, light ? 0.8 : 0.10) : Qt.alpha(ink, (light ? 0.09 : 0.11) + 0.10 * (1 - op))
    readonly property color border: Qt.alpha(ink, styleMode === "solid" ? 0.14 : (light ? 0.12 : 0.08))
    readonly property color track: Qt.alpha(ink, light ? 0.14 : 0.16)
    readonly property color scrim: Qt.rgba(0, 0, 0, light ? 0.28 : 0.5)

    // ---- strokes, separators, shadows: one switch each, honoured everywhere ----
    readonly property int   strokeWidth: shellBorders ? 1 : 0
    readonly property color stroke: shellBorders ? border : "transparent"
    readonly property color separator: shellBorders ? border : "transparent"
    readonly property color shadowColor: shadows ? (light ? "#26000000" : "#44000000") : "transparent"

    // ---- lock screen (kept for Lock*: LockStyle copies these once per lock) ----
    readonly property color lockBg:     glass(1, 0)
    readonly property color lockTop:    glass(0.18 + 0.62 * op, whiteMix)
    readonly property color lockBottom: glass(0.24 + 0.62 * op, whiteMix * 0.5)
    readonly property real  lockBlur:   0.25 + 0.75 * glassOpacity

    // ---- text ----
    readonly property color text:  light ? rgb(mixA(palette.tint, [0, 0, 0], 0.72)) : (palette.text || "#f4f1ff")
    readonly property color muted: light ? rgb(mixA(palette.tint, [92, 92, 104], 0.45)) : (palette.muted || "#a9a6cc")
    readonly property color dim:   light ? Qt.alpha(muted, 0.7) : Qt.tint(muted, "#55000000")

    // ---- accent ----
    readonly property color accentBase: accentOverride !== "" ? accentOverride : rgb(palette.accent)
    readonly property color accent: light ? Qt.darker(accentBase, 1.25) : accentBase
    readonly property string accentHex: accentOverride !== "" ? accentOverride : "#" + hex(palette.accent)
    readonly property color onAccent: luminance(accent) > 0.55 ? "#14122a" : "#ffffff"

    // ---- semantic colours: stable meanings, tuned per mode for contrast ----
    readonly property color green:  light ? "#15803d" : "#a5f58b"
    readonly property color yellow: light ? "#a16207" : "#ffe45e"
    readonly property color red:    light ? "#dc2626" : "#ff6b86"
    readonly property color pink:   light ? "#be185d" : "#ff70c5"
    readonly property color cyan:   light ? "#0369a1" : "#8be0ff"
    readonly property color blue:   light ? "#1d4ed8" : "#70b8ff"
    readonly property color purple: light ? "#6d28d9" : "#b69aff"

    // ---- type ----
    property var fontList: Qt.fontFamilies()
    function refreshFonts() { fontList = Qt.fontFamilies() }
    readonly property bool hasInter: fontList.indexOf("Inter") >= 0
    readonly property string iconFont: "JetBrainsMono Nerd Font"
    readonly property string font: (fontFamily !== "" && fontList.indexOf(fontFamily) >= 0) ? fontFamily : (hasInter ? "Inter" : "Noto Sans")
    readonly property int fontXs: 10
    readonly property int fontSm: 11
    readonly property int fontMd: 12
    readonly property int fontLg: 13
    readonly property int fontXl: 17
    readonly property int fontHero: 22

    // ---- geometry ----
    readonly property int iconBar:    16
    readonly property int iconBarBox: 18
    readonly property int iconPanel:  17
    readonly property int iconBox:    22
    readonly property int islandHeight: Settings.barDensity === "comfortable" ? 30 : 26
    readonly property int barMargin:    3
    readonly property int pillGap:      6
    readonly property int barHeight:    islandHeight + barMargin * 2
    readonly property int pad: 16
    readonly property int radius: Math.round(18 * radiusScale)
    readonly property int controlRadius: Math.round(12 * radiusScale)
    readonly property int smallRadius: Math.round(9 * radiusScale)
    function pill(h) { return radiusScale >= 1 ? h / 2 : Math.max(2, h / 2 * radiusScale) }
    readonly property int barSideInset: 10
    readonly property int barButtonHeight: islandHeight
    readonly property int barIcon: Math.round(islandHeight * 0.66)          // 17 compact / 20 comfortable
    readonly property int barIconBox: barIcon + 2
    readonly property int barPillPadX: Math.round(islandHeight * 0.34)      // icon-only pill = 34 x 26
    readonly property int barLabelSize: Settings.barDensity === "comfortable" ? 13 : 12
    readonly property real pillStrokeAlpha: light ? 0.10 : 0.09
    readonly property color pillStroke: shellBorders ? Qt.alpha(ink, pillStrokeAlpha) : "transparent"
    readonly property color pillSheen: light ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.07)
    readonly property color pillHover: Qt.alpha(ink, light ? 0.06 : 0.08)
    readonly property color pillPress: Qt.alpha(ink, light ? 0.11 : 0.14)
    function barTone(c) { return Settings.barIconStyle === "mono" ? text : c }
    readonly property int barButtonPadding: 6
    readonly property int barButtonGap: 6
    readonly property int islandInset: 2
    readonly property int popupInset: 16
    readonly property int popupOverscan: 12
    readonly property int popupEdgeInset: 10
    readonly property int dropdownGap: 9
    readonly property int settingsGap: 10
    readonly property int settingsSectionGap: 6

    // ---- motion: every duration goes through here so speed / reduced motion apply everywhere ----
    readonly property real motion: animations ? 1 / animSpeed : 0
    function dur(ms) { return Math.round(ms * motion) }
    readonly property int durFast: dur(120)
    readonly property int durBase: dur(180)
    readonly property int durSlow: dur(320)
    readonly property int easeOut: Easing.OutCubic

    // ---- icons (Material Design Nerd Font code points) ----
    readonly property var ic: ({
        bell: 0xF009A, bellOff: 0xF009B, bellRing: 0xF009E, clipboard: 0xF0192,
        volHigh: 0xF057E, volMed: 0xF0580, volLow: 0xF057F, volOff: 0xF0581,
        wifi: 0xF05A9, wifiOff: 0xF05AA,
        bt: 0xF00AF, btConnected: 0xF00B1, btOff: 0xF00B2,
        mic: 0xF036C, micOff: 0xF036D,
        sun: 0xF00E0, brightness: 0xF00DF,
        power: 0xF0425, lock: 0xF033E, suspend: 0xF04B2, logout: 0xF0343, restart: 0xF0709,
        refresh: 0xF0450, close: 0xF0156, trash: 0xF01B4, search: 0xF0349, copy: 0xF018F,
        left: 0xF0141, right: 0xF0142, up: 0xF0143, down: 0xF0140, cog: 0xF0493, check: 0xF012C, image: 0xF02E9,
        battery: 0xF0079, battery90: 0xF0082, battery80: 0xF0081, battery70: 0xF0080,
        battery60: 0xF007F, battery50: 0xF007E, battery40: 0xF007D, battery30: 0xF007C,
        battery20: 0xF007B, battery10: 0xF007A, batteryAlert: 0xF0083, batteryCharging: 0xF0084,
        leaf: 0xF032A, scale: 0xF0A8E, rocket: 0xF14DE,
        palette: 0xF03D8, snow: 0xF0717, moon: 0xF0594, lightDark: 0xF050E,
        keyboard: 0xF030C, monitor: 0xF0379, info: 0xF02FC, speed: 0xF04C5, dashboard: 0xF056E,
        wallpaper: 0xF02F9, window: 0xF05AF, plus: 0xF0415, pencil: 0xF03EB, exportFile: 0xF0207, importFile: 0xF02FA,
        play: 0xF040A, pause: 0xF03E4, next: 0xF04AD, prev: 0xF04AE, music: 0xF075A,
        eye: 0xF0208, eyeOff: 0xF0209, save: 0xF0193, restore: 0xF099B, alert: 0xF0026, folder: 0xF024B,
        shuffle: 0xF049D, drop: 0xF058C, apps: 0xF003B, font: 0xF06D6, terminal: 0xF018D,
        download: 0xF01DA, cursor: 0xF01C0, mouse: 0xF037D, handwriting: 0xF0F49, pen: 0xF0D13, text: 0xF0284,
        cloud: 0xF0162, folderDownload: 0xF024D, web: 0xF059F, swatch: 0xF08B5, link: 0xF0339, pack: 0xF03D7, star: 0xF04CE
    })
    function glyph(code) { return code > 0 ? String.fromCodePoint(code) : "" }

    // ---- modern icon set: Material Symbols Rounded (variable: FILL / wght) ----
    // name: [Material Symbols code point, MDI (Nerd Font) fallback]
    readonly property string symbolFont: "Material Symbols Rounded"
    readonly property bool hasSymbols: fontList.indexOf(symbolFont) >= 0
    readonly property var sym: ({
        bell: [0xE7F5, 0xF009A], bellOff: [0xE7F6, 0xF009B], bellRing: [0xE7F7, 0xF009E],
        clipboard: [0xE14F, 0xF0192], palette: [0xE40A, 0xF03D8],
        volHigh: [0xE050, 0xF057E], volMed: [0xE04D, 0xF0580], volLow: [0xE04E, 0xF057F], volOff: [0xE04F, 0xF0581],
        wifi: [0xE63E, 0xF05A9], wifi2: [0xE4D9, 0xF0922], wifi1: [0xE4CA, 0xF091F], wifiFind: [0xEB31, 0xF05A9], wifiOff: [0xE648, 0xF05AA], lan: [0xEB2F, 0xF0200],
        bt: [0xE1A7, 0xF00AF], btConnected: [0xE1A8, 0xF00B1], btOff: [0xE1A9, 0xF00B2],
        batFull: [0xE1A5, 0xF0079], bat6: [0xF0A1, 0xF0082], bat5: [0xF0A0, 0xF0080], bat4: [0xF09F, 0xF007F], bat3: [0xF09E, 0xF007D],
        bat2: [0xF09D, 0xF007C], bat1: [0xF09C, 0xF007A], bat0: [0xEBDC, 0xF0083], batCharging: [0xE1A3, 0xF0084], batAlert: [0xE19C, 0xF0083],
        power: [0xF8C7, 0xF0425], micOff: [0xE02B, 0xF036D], play: [0xE037, 0xF040A], pause: [0xE034, 0xF03E4],
        music: [0xE405, 0xF075A], brightness: [0xE518, 0xF00DF],
        lock: [0xE899, 0xF033E], arrowForward: [0xE5C8, 0xF0054], spinner: [0xE9D0, 0xF0450], sleep: [0xF159, 0xF04B2],
        restart: [0xF053, 0xF0709], skipNext: [0xE044, 0xF04AD], skipPrev: [0xE045, 0xF04AE]
    })
    function batterySym(cap, state) {
        if (state === "Charging") return "batCharging"
        if (cap < 8) return "batAlert"
        var lv = ["bat0", "bat1", "bat2", "bat3", "bat4", "bat5", "bat6", "batFull"]
        return lv[Math.max(0, Math.min(7, Math.round(cap / 100 * 7)))]
    }
    function volumeSym(vol, muted) { return muted || vol === 0 ? "volOff" : (vol < 34 ? "volLow" : (vol < 67 ? "volMed" : "volHigh")) }
    function wifiSym(on, ssid, signal) {
        if (!on) return "wifiOff"
        if (ssid === "") return "wifiFind"
        return signal >= 60 || signal === 0 ? "wifi" : (signal >= 30 ? "wifi2" : "wifi1")
    }

    function batteryIcon(cap, state) {
        if (state === "Charging") return ic.batteryCharging
        if (cap < 10) return ic.batteryAlert
        if (cap < 20) return ic.battery10
        if (cap < 30) return ic.battery20
        if (cap < 40) return ic.battery30
        if (cap < 50) return ic.battery40
        if (cap < 60) return ic.battery50
        if (cap < 70) return ic.battery60
        if (cap < 80) return ic.battery70
        if (cap < 90) return ic.battery80
        if (cap < 97) return ic.battery90
        return ic.battery
    }
    function batteryColor(cap, state) {
        if (state === "Charging") return cyan
        if (cap < 15) return red
        if (cap < 30) return yellow
        return green
    }
    function timeAgo(ms) {
        var s = Math.max(0, Math.round((Date.now() - ms) / 1000))
        if (s < 60) return "now"
        if (s < 3600) return Math.floor(s / 60) + "m"
        if (s < 86400) return Math.floor(s / 3600) + "h"
        return Math.floor(s / 86400) + "d"
    }

    // =========================================================================
    //  persistence
    // =========================================================================
    Process { id: mkdirP; command: ["mkdir", "-p", theme.configDir]; running: true }

    FileView {
        id: store
        path: theme.configDir + "/appearance.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }
    FileView {
        id: themesStore
        path: theme.configDir + "/themes.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }
    // pre-Sleek Shell location, read once for migration
    FileView { id: legacyStore; path: Quickshell.statePath("appearance.json"); blockLoading: true; printErrors: false }

    Timer { id: saveTimer; interval: 400; onTriggered: theme.writeStore() }
    function writeStore() {
        var o = snapshot(); o.activeTheme = activeTheme; o.version = 1
        store.setText(JSON.stringify(o, null, 2) + "\n")
    }
    function writeThemes() { themesStore.setText(JSON.stringify({ version: 1, themes: userThemes }, null, 2) + "\n") }

    function loadAll() {
        var raw = null, src = "current"
        try { var t = store.text(); if (t && t.trim() !== "") raw = JSON.parse(t) } catch (e) { raw = null; src = "invalid" }
        if (!raw) {
            try {
                var lt = legacyStore.text()
                if (lt && lt.trim() !== "") { raw = JSON.parse(lt); src = "legacy" }
            } catch (e2) { raw = null }
        }
        raw = raw || {}
        for (var i = 0; i < themeKeys.length; ++i) {
            var k = themeKeys[i]
            theme[propOf[k]] = sanitize(k, k in raw ? raw[k] : defaults[k])
        }
        activeTheme = sanitize("activeTheme", raw.activeTheme || "")
        try {
            var tt = JSON.parse(themesStore.text() || "{}")
            var list = []
            ;(tt.themes || []).forEach(function (x) {
                if (!x || typeof x.name !== "string" || typeof x.values !== "object") return
                var v = {}
                themeKeys.forEach(function (k) { v[k] = sanitize(k, k in x.values ? x.values[k] : defaults[k]) })
                list.push({ name: cleanName(x.name) || "Untitled", created: x.created || 0, values: v })
            })
            userThemes = list
        } catch (e3) { userThemes = [] }
        loaded = true
        if (src !== "current") writeStore()
        if (src === "invalid") lastMessage = "appearance.json was invalid; restored defaults"
    }

    Component.onCompleted: {
        loadAll()
        loadApps()
        applyHypr()
        applyMode()
        exportTimer.restart()
    }

    // =========================================================================
    //  compositor sync (hypr/sleekshell/look.lua reads the generated file; survives reloads)
    // =========================================================================
    FileView { id: hyprLook; path: theme.configDir + "/hypr-look.lua"; printErrors: false; atomicWrites: true }
    Process {
        id: hyprApply
        stdout: StdioCollector { id: hyprOut }
        stderr: StdioCollector { id: hyprErr }
        onExited: code => {
            theme.compositorStatus = code === 0 ? "Applied to windows" : "Hyprland: " + ((hyprOut.text + hyprErr.text).trim() || "IPC unavailable")
            if (theme.hyprPending) { theme.hyprPending = false; applyTimer.restart() }
        }
    }
    property bool hyprPending: false
    Timer {
        id: applyTimer
        interval: 90
        onTriggered: {
            if (hyprApply.running) { theme.hyprPending = true; return }
            var lua = "-- Generated by Sleek Shell Settings. Do not edit by hand; use Settings (SUPER+I).\nreturn {\n" +
                "    border_width = " + theme.borderWidth + ", colorful = " + theme.colorfulBorders +
                ", accent = \"" + theme.accentHex.replace("#", "") + "\", secondary = \"" + theme.hex(theme.palette.accent) + "\", inactive = \"66667888\",\n" +
                "    blur_enabled = " + (theme.styleMode === "glass") + ", blur_size = " + theme.blurSize + ", blur_passes = " + theme.blurPasses +
                ", blur_brightness = " + (theme.blurBrightness / 100).toFixed(2) + ",\n" +
                "    rounding = " + theme.windowRounding + ", gaps_in = " + theme.gapsIn + ", gaps_out = " + theme.gapsOut +
                ", active_opacity = " + theme.activeOpacity.toFixed(2) + ", inactive_opacity = " + theme.inactiveOpacity.toFixed(2) + ",\n" +
                "    shadows = " + theme.windowShadows + ", anim_enabled = " + theme.animations + ", anim_speed = " + theme.animSpeed.toFixed(2) + ",\n}\n"
            hyprLook.setText(lua)
            hyprApply.command = ["hyprctl", "eval", "require('sleekshell.look').apply()"]
            theme.compositorStatus = "Applying…"
            hyprApply.running = true
        }
    }
    function applyHypr() { applyTimer.restart() }

    function applyMode() {
        Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/apply-mode.sh"), theme.mode])
    }

    // =========================================================================
    //  per-app theming (~/.config/sleek-shell/app-themes.json, separate from saved themes)
    //  scope "all": every supported app follows the shell unless excluded
    //  scope "selected": only apps set to "inherit" or "custom" are themed
    // =========================================================================
    readonly property var themedApps: [
        { id: "kitty", name: "Kitty", icon: "terminal", what: "~/.config/kitty/theme.conf", when: "New kitty windows (Ctrl+Shift+F5 reloads open ones)", offNote: "Kitty goes back to the colours in your kitty.conf." },
        { id: "rofi",  name: "Rofi launcher", icon: "apps", what: "~/.config/rofi/themes/rice.rasi", when: "Next time the launcher opens", offNote: "The launcher keeps its last colours." },
        { id: "gtk",   name: "GTK 3 / 4 apps", icon: "window", what: "~/.config/gtk-3.0 and gtk-4.0/gtk.css", when: "Restart the app", offNote: "Sleek Shell stops editing gtk.css; the last accent stays until you change it." },
        { id: "qt",    name: "Qt / KDE apps", icon: "folder", what: "~/.config/kdeglobals", when: "Most KDE apps update live; others on restart", offNote: "Sleek Shell stops editing kdeglobals; pick a colour scheme in your Qt settings." },
        { id: "micro", name: "micro editor", icon: "terminal", what: "~/.config/micro/colorschemes/rice.micro", when: "Next time micro starts", offNote: "Select another colorscheme in micro." }
    ]
    property string appScope: "all"
    property var    appRules: ({})         // { id: { mode: "inherit"|"custom"|"off", palette: "", accent: "" } }
    FileView { id: appStore; path: theme.configDir + "/app-themes.json"; blockLoading: true; printErrors: false; atomicWrites: true }
    function loadApps() {
        var o = {}
        try { o = JSON.parse(appStore.text() || "{}") } catch (e) { o = {} }
        appScope = o.scope === "selected" ? "selected" : "all"
        var r = {}
        themedApps.forEach(function (a) {
            var x = o.apps && o.apps[a.id]
            if (!x || ["inherit", "custom", "off"].indexOf(x.mode) < 0) return
            r[a.id] = { mode: x.mode, palette: sanitize("palette", x.palette || paletteId), accent: normHex(x.accent || "") }
        })
        appRules = r
    }
    function saveApps() {
        appStore.setText(JSON.stringify({ version: 1, scope: appScope, apps: appRules }, null, 2) + "\n")
        exportTimer.restart()
    }
    function appMode(id) { var x = appRules[id]; return x ? x.mode : (appScope === "all" ? "inherit" : "off") }
    function appRule(id) { return appRules[id] || { mode: appMode(id), palette: paletteId, accent: "" } }
    function setAppScope(s) { appScope = s === "selected" ? "selected" : "all"; saveApps() }
    function setAppRule(id, patch) {
        if (!themedApps.some(function (a) { return a.id === id })) return
        var r = Object.assign({}, appRules), cur = Object.assign({}, appRule(id), patch)
        cur.palette = sanitize("palette", cur.palette); cur.accent = normHex(cur.accent || "")
        if (["inherit", "custom", "off"].indexOf(cur.mode) < 0) cur.mode = "inherit"
        r[id] = cur; appRules = r; saveApps()
    }
    function resetApps() { appScope = "all"; appRules = ({}); saveApps() }
    function appColours(id) {
        var m = appMode(id)
        if (m === "off") return { on: false }
        if (m !== "custom") return { on: true }
        var x = appRule(id), p = findPalette(x.palette)
        return { on: true, tintR: p.tint[0], tintG: p.tint[1], tintB: p.tint[2], accent: x.accent || "#" + hex(p.accent),
                 text: p.text, muted: p.muted, dim: "" + Qt.tint(p.muted, "#55000000") }
    }
    function themedSummary() {
        var on = themedApps.filter(function (a) { return appMode(a.id) !== "off" }).length
        return on + " of " + themedApps.length + " apps follow Sleek Shell"
    }

    // ---- export colours for external apps (kitty / rofi / GTK / KDE / micro) ----
    Timer {
        id: exportTimer
        interval: 600
        onTriggered: {
            var o = {
                theme: theme.paletteId, tintR: theme.palette.tint[0], tintG: theme.palette.tint[1], tintB: theme.palette.tint[2],
                accent: theme.accentHex, text: "" + (theme.palette.text || "#f4f1ff"), muted: "" + (theme.palette.muted || "#a9a6cc"),
                dim: "" + Qt.tint(theme.palette.muted || "#a9a6cc", "#55000000"),
                glass: Math.round(theme.glassOpacity * 100) / 100, blur: theme.blurSize, mode: theme.mode,
                styleMode: theme.styleMode, apps: {}
            }
            theme.themedApps.forEach(function (a) { o.apps[a.id] = theme.appColours(a.id) })
            var s = JSON.stringify(o, null, 2)
            if (s === theme.lastExport) return
            theme.lastExport = s
            exportStore.setText(s + "\n")
        }
    }
    property string lastExport: ""
    FileView {
        id: exportStore
        path: theme.configDir + "/theme-export.json"
        printErrors: false
        atomicWrites: true
        onSaved: Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/apply-theme.sh"), exportStore.path])
    }
}
