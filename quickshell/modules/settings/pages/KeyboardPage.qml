import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components
import qs.modules.settings

// Settings > Keyboard: every Hyprland shortcut (built-in and custom) in one searchable, grouped list.
// Built-in binds can be moved to other keys, disabled and restored; custom binds can be created,
// edited, disabled and deleted. Source of truth: ~/.config/sleek-shell/keybinds.json (via hypr-tools.py),
// which validates, refuses conflicts, regenerates the Lua, reloads Hyprland and rolls back on errors.
Item {
    id: kp
    readonly property string tools: Quickshell.env("HOME") + "/.config/hypr/scripts/hypr-tools.py"
    property var binds: []
    property var model: ({ overrides: { disabled: [], remap: {} }, custom: [] })
    property var actions: ({ dispatch: [], shell: [] })
    property bool loading: true
    property bool busy: false
    property string msg: ""
    property bool bad: false
    property string query: ""
    property string cat: "All"
    property var sel: null          // selected bind record
    property var edit: null         // custom editor state
    property string newKeys: ""     // pending keys for a built-in remap
    property bool capturing: false
    property string captureFor: ""  // "remap" | "custom"
    readonly property var cats: ["All", "Applications", "Windows", "Workspaces", "Shell", "Media & hardware", "Screenshots", "Desktop", "Session", "Custom", "Disabled"]

    // ------------------------------------------------------------------ data
    function load() { loading = true; listP.running = true }
    Component.onCompleted: { load(); actP.running = true }
    Process {
        id: listP
        command: ["python3", kp.tools, "binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                kp.loading = false
                var r; try { r = JSON.parse(text) } catch (e) { r = { ok: false, error: "unreadable helper output" } }
                if (!r.ok) { kp.msg = "Could not read shortcuts: " + r.error; kp.bad = true; return }
                kp.binds = r.binds; kp.model = r.model
                if (r.conflicts && r.conflicts.length) { kp.msg = "Conflict: " + r.conflicts[0].keys + " is bound twice"; kp.bad = true }
                if (kp.sel) { var s = kp.find(kp.sel.id); kp.sel = s }
            }
        }
    }
    Process {
        id: actP
        command: ["python3", kp.tools, "actions"]
        stdout: StdioCollector { onStreamFinished: { try { var r = JSON.parse(text); if (r.ok) kp.actions = r } catch (e) {} } }
    }
    Process {
        id: saveP
        stdout: StdioCollector {
            onStreamFinished: {
                kp.busy = false
                var r; try { r = JSON.parse(text) } catch (e) { r = { ok: false, error: "unreadable helper output" } }
                kp.bad = !r.ok
                kp.msg = r.ok ? (r.message || (r.path ? "Exported to " + r.path.replace(Quickshell.env("HOME"), "~") : "Saved")) : r.error
                if (r.ok && !r.path) { kp.edit = null; kp.newKeys = "" }
                kp.load()
            }
        }
    }
    Process {
        id: valP
        stdout: StdioCollector {
            onStreamFinished: {
                var r; try { r = JSON.parse(text) } catch (e) { return }
                if (!kp.edit) return
                var e = JSON.parse(JSON.stringify(kp.edit)); e.check = r; kp.edit = e
            }
        }
    }
    function find(id) { for (var i = 0; i < binds.length; ++i) if (binds[i].id === id) return binds[i]; return null }
    function saveModel(m) {
        busy = true; msg = "Applying…"; bad = false
        saveP.command = ["python3", tools, "save", JSON.stringify(m)]
        saveP.running = true
    }
    function cloneModel() { return JSON.parse(JSON.stringify(model)) }

    // ------------------------------------------------------------------ keys
    readonly property var modMap: ({ SUPER: "SUPER", MOD4: "SUPER", WIN: "SUPER", META: "SUPER", SHIFT: "SHIFT", CTRL: "CTRL", CONTROL: "CTRL", ALT: "ALT", MOD1: "ALT" })
    function norm(keys) {
        var t = String(keys).split("+").map(function (x) { return x.trim() }).filter(function (x) { return x !== "" })
        var mods = {}, key = ""
        for (var i = 0; i < t.length; ++i) {
            var u = t[i].toUpperCase()
            if (i < t.length - 1 && modMap[u]) mods[modMap[u]] = true; else key = t[i].toLowerCase()
        }
        return Object.keys(mods).sort().join("+") + "|" + key
    }
    function keyParts(keys) { return String(keys).split("+").map(function (x) { return x.trim() }).filter(function (x) { return x !== "" }) }
    function conflictsFor(keys, selfId) {
        var n = norm(keys), out = []
        if (keys.trim() === "") return out
        for (var i = 0; i < binds.length; ++i) {
            var b = binds[i]
            if (b.id === selfId || !b.enabled) continue
            if (b.norm === n) out.push(b)
        }
        return out
    }
    function keyName(k, text) {
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k)
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k)
        if (k >= Qt.Key_F1 && k <= Qt.Key_F24) return "F" + (k - Qt.Key_F1 + 1)
        var m = ({}); m[Qt.Key_Tab] = "Tab"; m[Qt.Key_Backtab] = "Tab"; m[Qt.Key_Return] = "Return"; m[Qt.Key_Enter] = "Return"; m[Qt.Key_Space] = "space"
        m[Qt.Key_Left] = "left"; m[Qt.Key_Right] = "right"; m[Qt.Key_Up] = "up"; m[Qt.Key_Down] = "down"; m[Qt.Key_Print] = "Print"; m[Qt.Key_Delete] = "Delete"
        m[Qt.Key_Home] = "Home"; m[Qt.Key_End] = "End"; m[Qt.Key_PageUp] = "Prior"; m[Qt.Key_PageDown] = "Next"; m[Qt.Key_Minus] = "minus"; m[Qt.Key_Equal] = "equal"
        m[Qt.Key_Comma] = "comma"; m[Qt.Key_Period] = "period"; m[Qt.Key_Slash] = "slash"; m[Qt.Key_Backslash] = "backslash"; m[Qt.Key_Semicolon] = "semicolon"
        m[Qt.Key_Apostrophe] = "apostrophe"; m[Qt.Key_BracketLeft] = "bracketleft"; m[Qt.Key_BracketRight] = "bracketright"; m[Qt.Key_QuoteLeft] = "grave"
        m[Qt.Key_Backspace] = "BackSpace"; m[Qt.Key_Insert] = "Insert"; m[Qt.Key_Escape] = "Escape"
        m[Qt.Key_VolumeUp] = "XF86AudioRaiseVolume"; m[Qt.Key_VolumeDown] = "XF86AudioLowerVolume"; m[Qt.Key_VolumeMute] = "XF86AudioMute"
        m[Qt.Key_MediaPlay] = "XF86AudioPlay"; m[Qt.Key_MediaNext] = "XF86AudioNext"; m[Qt.Key_MediaPrevious] = "XF86AudioPrev"
        return m[k] || ""
    }
    function startCapture(target) {
        captureFor = target; capturing = true
        Sys.run(["hyprctl", "dispatch", "hl.dsp.submap(\"sleekshell_capture\")"])
        catcher.forceActiveFocus()
    }
    function stopCapture() {
        if (!capturing) return
        capturing = false
        Sys.run(["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"])
    }
    Component.onDestruction: stopCapture()
    Connections { target: Ui; function onSettingsOpenChanged() { if (!Ui.settingsOpen) kp.stopCapture() } }
    function captured(e) {
        if (e.key === Qt.Key_Escape && !(e.modifiers & (Qt.MetaModifier | Qt.ControlModifier | Qt.AltModifier))) { stopCapture(); return }
        var n = keyName(e.key, e.text)
        if (n === "") return
        var mods = []
        if (e.modifiers & Qt.MetaModifier) mods.push("SUPER")
        if (e.modifiers & Qt.ControlModifier) mods.push("CTRL")
        if (e.modifiers & Qt.AltModifier) mods.push("ALT")
        if (e.modifiers & Qt.ShiftModifier) mods.push("SHIFT")
        var keys = mods.concat([n]).join(" + ")
        if (captureFor === "remap") newKeys = keys
        else if (edit) setE("keys", keys)
        stopCapture()
    }

    // ------------------------------------------------------------------ list
    function rows() {
        var q = query.toLowerCase(), out = []
        for (var i = 0; i < binds.length; ++i) {
            var b = binds[i]
            if (cat === "Disabled") { if (b.enabled) continue }
            else if (cat === "Custom") { if (b.kind !== "custom") continue }
            else if (cat !== "All" && b.category !== cat) continue
            if (q && (b.keys + " " + b.label + " " + b.action + " " + b.category + " " + b.source).toLowerCase().replace(/\s*\+\s*/g, " ").indexOf(q.replace(/\s*\+\s*/g, " ")) < 0) continue
            out.push({ b: b, i: i })
        }
        var order = cats
        out.sort(function (x, y) { return (order.indexOf(x.b.category) - order.indexOf(y.b.category)) || (x.i - y.i) })
        out = out.map(function (x) { return x.b })
        return out
    }

    // ------------------------------------------------------------------ built-in actions
    function setBuiltinEnabled(b, on) {
        var m = cloneModel(), d = m.overrides.disabled.filter(function (n) { return n !== b.origNorm })
        if (!on) d.push(b.origNorm)
        m.overrides.disabled = d
        saveModel(m)
    }
    function remapBuiltin(b, keys) {
        var m = cloneModel()
        if (norm(keys) === b.origNorm) delete m.overrides.remap[b.origNorm]
        else m.overrides.remap[b.origNorm] = keys
        saveModel(m)
    }
    function restoreBuiltin(b) {
        var m = cloneModel()
        delete m.overrides.remap[b.origNorm]
        m.overrides.disabled = m.overrides.disabled.filter(function (n) { return n !== b.origNorm })
        saveModel(m)
    }

    // ------------------------------------------------------------------ custom editor
    function startNew() {
        sel = null; newKeys = ""
        edit = { id: "c" + Date.now(), keys: "", kind: "app", value: "", args: "", app: "", desc: "", enabled: true, flags: {}, confirmed: false, isNew: true, check: null, appQuery: "" }
    }
    function startEdit(b) {
        var it = b.item
        edit = { id: it.id, keys: it.keys, kind: it.kind, value: it.value, args: it.args || "", app: it.app || "", desc: it.desc || "", enabled: it.enabled !== false,
                 flags: it.flags || {}, confirmed: !!it.confirmed, isNew: false, check: null, appQuery: "" }
        validate()
    }
    function setE(k, v) { var e = JSON.parse(JSON.stringify(edit)); e[k] = v; e.check = null; edit = e; valT.restart() }
    Timer { id: valT; interval: 350; onTriggered: kp.validate() }
    function editItem() {
        var e = edit
        var it = { id: e.id, keys: e.keys, kind: e.kind, value: e.value, desc: e.desc, enabled: e.enabled, flags: e.flags }
        if (e.kind === "script" && e.args) it.args = e.args
        if (e.kind === "app" && e.app) it.app = e.app
        if (e.confirmed) it.confirmed = true
        return it
    }
    function validate() {
        if (!edit || edit.value.trim() === "" || edit.keys.trim() === "") return
        valP.command = ["python3", tools, "validate", JSON.stringify(editItem())]
        valP.running = true
    }
    function saveCustom() {
        if (!edit) return
        if (edit.keys.trim() === "") { msg = "Record or type a shortcut first"; bad = true; return }
        if (edit.value.trim() === "") { msg = "Choose what the shortcut should do"; bad = true; return }
        var c = conflictsFor(edit.keys, "c:" + edit.id)
        if (c.length) { msg = edit.keys + " is already used by “" + c[0].label + "”. Pick another shortcut or disable that one first."; bad = true; return }
        var m = cloneModel(), it = editItem()
        m.custom = m.custom.filter(function (x) { return x.id !== it.id })
        m.custom.push(it)
        saveModel(m)
    }
    function deleteCustom(id) {
        var m = cloneModel()
        m.custom = m.custom.filter(function (x) { return x.id !== id })
        sel = null; edit = null
        saveModel(m)
    }
    function setCustomEnabled(b, on) {
        var m = cloneModel()
        m.custom.forEach(function (x) { if (x.id === b.item.id) x.enabled = on })
        saveModel(m)
    }

    // ================================================================== UI
    FocusScope {
        id: catcher
        anchors.fill: parent
        Keys.onPressed: e => { if (kp.capturing) { kp.captured(e); e.accepted = true } }

        ColumnLayout {
            anchors { fill: parent; leftMargin: 24; rightMargin: 24; topMargin: 22; bottomMargin: 16 }
            spacing: 12

            // header
            RowLayout {
                Layout.fillWidth: true
                Layout.rightMargin: 40
                spacing: 10
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Text { text: "Keyboard shortcuts"; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontHero; font.weight: Font.Bold }
                    Text { text: kp.loading ? "Reading your configuration…" : kp.binds.length + " shortcuts · " + kp.binds.filter(function (b) { return b.kind === "custom" }).length + " custom · " + kp.binds.filter(function (b) { return !b.enabled }).length + " disabled"
                           color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontMd }
                }
                Item { Layout.fillWidth: true }
                UiBtn { label: "New shortcut"; code: Theme.ic.plus; selected: true; onClicked: kp.startNew() }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                UiField { Layout.fillWidth: true; implicitHeight: 36; code: Theme.ic.search; placeholder: "Search by key, action, app or category  (e.g. “super t”, “screenshot”, “kitty”)"
                          onEdited: kp.query = text }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: kp.cats
                    delegate: UiBtn {
                        required property string modelData
                        implicitHeight: 26
                        label: modelData
                        selected: kp.cat === modelData
                        onClicked: kp.cat = modelData
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // ---------------- list
                Rectangle {
                    id: listCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 320
                    radius: Theme.radius
                    color: Theme.surface
                    border.width: Theme.strokeWidth; border.color: Theme.stroke
                    clip: true
                    ListView {
                        id: list
                        anchors { fill: parent; margins: 6 }
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: kp.rows()
                        section.property: "category"
                        section.delegate: Text {
                            required property string section
                            width: list.width
                            topPadding: 10; bottomPadding: 4; leftPadding: 8
                            text: section.toUpperCase()
                            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontXs; font.weight: Font.DemiBold; font.letterSpacing: 1
                        }
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            readonly property bool selected: kp.sel && kp.sel.id === modelData.id
                            width: list.width
                            height: 42
                            radius: Theme.controlRadius
                            color: selected ? Qt.alpha(Theme.accent, 0.20) : (rma.containsMouse ? Theme.surfaceHi : "transparent")
                            opacity: modelData.enabled ? 1 : 0.55
                            Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                spacing: 10
                                KeyCaps { keys: row.modelData.keys; Layout.preferredWidth: 150; Layout.maximumWidth: 150 }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text { text: row.modelData.label; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontLg; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: row.modelData.action; color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontXs; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                                Badge { visible: row.modelData.kind === "custom"; text: "custom"; tone: Theme.green }
                                Badge { visible: row.modelData.remapped; text: "changed"; tone: Theme.cyan }
                                Badge { visible: !row.modelData.enabled; text: "off"; tone: Theme.muted }
                                Badge { visible: !!row.modelData.problem; text: "problem"; tone: Theme.red }
                            }
                            MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { kp.stopCapture(); kp.sel = row.modelData; kp.newKeys = ""; kp.edit = null; if (row.modelData.kind === "custom") kp.startEdit(row.modelData) } }
                        }
                    }
                    Empty { anchors.centerIn: parent; visible: !kp.loading && list.count === 0; code: Theme.ic.keyboard; title: "No shortcuts match"; hint: "Try another search or category" }
                }

                // ---------------- inspector / editor
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: Math.max(330, Math.min(420, parent.width * 0.42))
                    radius: Theme.radius
                    color: Theme.surface
                    border.width: Theme.strokeWidth; border.color: Theme.stroke
                    clip: true
                    Flickable {
                        anchors { fill: parent; margins: 14 }
                        contentHeight: side.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: side
                            width: parent.width
                            spacing: 10

                            // nothing selected
                            ColumnLayout {
                                visible: !kp.sel && !kp.edit
                                Layout.fillWidth: true
                                spacing: 8
                                Glyph { code: Theme.ic.keyboard; size: 30; color: Theme.dim; implicitWidth: 36; implicitHeight: 36 }
                                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontMd
                                       text: "Select a shortcut to change its keys, turn it off, or edit it.\n\nUse “New shortcut” to launch an app, run a command or script, or trigger a desktop action.\n\nShortcuts inside apps (like Ctrl+Tab in a browser) are not listed; a desktop shortcut on the same keys wins over them." }
                            }

                            // ---- built-in inspector
                            ColumnLayout {
                                visible: !!kp.sel && kp.sel.kind === "builtin"
                                Layout.fillWidth: true
                                spacing: 10
                                Text { text: kp.sel ? kp.sel.label : ""; color: Theme.text; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                KeyCaps { keys: kp.sel ? kp.sel.keys : ""; big: true }
                                Text { Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm
                                       text: kp.sel ? kp.sel.action + "\n" + kp.sel.category + " · " + kp.sel.source + (kp.sel.line ? ":" + kp.sel.line : "") + (kp.sel.flags.length ? " · " + kp.sel.flags.join(", ") : "") + (kp.sel.remapped ? "\nDefault: " + kp.sel.origKeys : "") : "" }
                                Divider {}
                                SectionLabel { title: "Change shortcut" }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    UiField { id: remapField; Layout.fillWidth: true; placeholder: "e.g. SUPER + ALT + T"; text: kp.newKeys; onEdited: kp.newKeys = text
                                              error: kp.newKeys !== "" && kp.conflictsFor(kp.newKeys, kp.sel ? kp.sel.id : "").length > 0 }
                                    UiBtn { label: kp.capturing && kp.captureFor === "remap" ? "Press keys…" : "Record"; selected: kp.capturing && kp.captureFor === "remap"
                                            onClicked: kp.capturing ? kp.stopCapture() : kp.startCapture("remap") }
                                }
                                ConflictNote { page: kp; keys: kp.newKeys; selfId: kp.sel ? kp.sel.id : "" }
                                RowLayout {
                                    spacing: 6
                                    UiBtn { label: "Apply"; selected: true; enabled: !kp.busy && kp.newKeys.trim() !== "" && kp.conflictsFor(kp.newKeys, kp.sel ? kp.sel.id : "").length === 0
                                            onClicked: kp.remapBuiltin(kp.sel, kp.newKeys) }
                                    UiBtn { label: "Restore default"; visible: kp.sel && (kp.sel.remapped || !kp.sel.enabled); enabled: !kp.busy; onClicked: kp.restoreBuiltin(kp.sel) }
                                }
                                Divider {}
                                SettingRow {
                                    title: "Enabled"
                                    subtitle: kp.sel && !kp.sel.enabled ? "Off: the keys are free for something else" : "Turn off to free these keys"
                                    Toggle { enabled: !kp.busy; checked: !!kp.sel && kp.sel.enabled; accessibleName: "Shortcut enabled"; onToggled: kp.setBuiltinEnabled(kp.sel, !kp.sel.enabled) }
                                }
                            }

                            // ---- custom editor
                            ColumnLayout {
                                visible: !!kp.edit
                                Layout.fillWidth: true
                                spacing: 10
                                Text { text: kp.edit && kp.edit.isNew ? "New shortcut" : "Edit shortcut"; color: Theme.text; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                                SectionLabel { title: "Keys" }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    UiField { Layout.fillWidth: true; placeholder: "e.g. SUPER + F1"; text: kp.edit ? kp.edit.keys : ""; onEdited: kp.setE("keys", text)
                                              error: !!kp.edit && kp.edit.keys !== "" && kp.conflictsFor(kp.edit.keys, "c:" + kp.edit.id).length > 0 }
                                    UiBtn { label: kp.capturing && kp.captureFor === "custom" ? "Press keys…" : "Record"; selected: kp.capturing && kp.captureFor === "custom"
                                            onClicked: kp.capturing ? kp.stopCapture() : kp.startCapture("custom") }
                                }
                                ConflictNote { page: kp; keys: kp.edit ? kp.edit.keys : ""; selfId: kp.edit ? "c:" + kp.edit.id : "" }
                                SectionLabel { title: "Action" }
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: [{ id: "app", l: "Open app" }, { id: "command", l: "Run command" }, { id: "script", l: "Run script" }, { id: "shell", l: "Desktop action" }, { id: "dispatch", l: "Window action" }]
                                        delegate: UiBtn { required property var modelData; label: modelData.l; selected: kp.edit && kp.edit.kind === modelData.id
                                                          onClicked: { kp.setE("kind", modelData.id); kp.setE("value", ""); kp.setE("app", "") } }
                                    }
                                }
                                // app picker
                                ColumnLayout {
                                    visible: !!kp.edit && kp.edit.kind === "app"
                                    Layout.fillWidth: true
                                    spacing: 6
                                    UiField { id: appSearch; Layout.fillWidth: true; code: Theme.ic.search; placeholder: kp.edit && kp.edit.app ? kp.edit.app : "Search installed apps"
                                              onEdited: kp.setE("appQuery", text) }
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 5
                                        Repeater {
                                            model: {
                                                if (!kp.edit || kp.edit.kind !== "app") return []
                                                var q = (kp.edit.appQuery || "").toLowerCase(), v = DesktopEntries.applications.values, out = []
                                                for (var i = 0; i < v.length && out.length < 10; ++i)
                                                    if (!v[i].noDisplay && (q === "" ? i < 10 : v[i].name.toLowerCase().indexOf(q) >= 0)) out.push(v[i])
                                                return out
                                            }
                                            delegate: UiBtn {
                                                required property var modelData
                                                label: modelData.name
                                                selected: kp.edit && kp.edit.app === modelData.name
                                                onClicked: { kp.setE("app", modelData.name); kp.setE("value", modelData.command.join(" ")) }
                                            }
                                        }
                                    }
                                    Text { visible: !!kp.edit && kp.edit.value !== ""; text: kp.edit ? "Runs: " + kp.edit.value : ""; color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }
                                }
                                // command
                                UiField {
                                    visible: !!kp.edit && kp.edit.kind === "command"
                                    Layout.fillWidth: true
                                    placeholder: "e.g. kitty -e btop"
                                    text: kp.edit && kp.edit.kind === "command" ? kp.edit.value : ""
                                    onEdited: kp.setE("value", text)
                                }
                                // script
                                ColumnLayout {
                                    visible: !!kp.edit && kp.edit.kind === "script"
                                    Layout.fillWidth: true
                                    spacing: 6
                                    UiField { Layout.fillWidth: true; code: Theme.ic.folder; placeholder: "~/bin/my-script.sh"; text: kp.edit && kp.edit.kind === "script" ? kp.edit.value : ""; onEdited: kp.setE("value", text) }
                                    UiField { Layout.fillWidth: true; placeholder: "arguments (optional)"; text: kp.edit ? kp.edit.args : ""; onEdited: kp.setE("args", text) }
                                }
                                // shell / dispatch catalogues
                                Flow {
                                    visible: !!kp.edit && (kp.edit.kind === "shell" || kp.edit.kind === "dispatch")
                                    Layout.fillWidth: true
                                    spacing: 5
                                    Repeater {
                                        model: kp.edit ? (kp.edit.kind === "shell" ? kp.actions.shell : (kp.edit.kind === "dispatch" ? kp.actions.dispatch : [])) : []
                                        delegate: UiBtn { required property var modelData; label: modelData.label; selected: kp.edit && kp.edit.value === modelData.id; onClicked: kp.setE("value", modelData.id) }
                                    }
                                }
                                UiField { Layout.fillWidth: true; placeholder: "Description (optional)"; text: kp.edit ? kp.edit.desc : ""; onEdited: kp.setE("desc", text) }
                                SettingRow {
                                    title: "Works on the lock screen"
                                    Toggle { checked: !!kp.edit && !!kp.edit.flags.locked; accessibleName: "Locked"
                                             onToggled: { var f = JSON.parse(JSON.stringify(kp.edit.flags)); f.locked = !f.locked; kp.setE("flags", f) } }
                                }
                                SettingRow {
                                    title: "Repeat while held"
                                    Toggle { checked: !!kp.edit && !!kp.edit.flags.repeating; accessibleName: "Repeating"
                                             onToggled: { var f = JSON.parse(JSON.stringify(kp.edit.flags)); f.repeating = !f.repeating; kp.setE("flags", f) } }
                                }
                                SettingRow {
                                    title: "Enabled"
                                    Toggle { checked: !!kp.edit && kp.edit.enabled; accessibleName: "Enabled"; onToggled: kp.setE("enabled", !kp.edit.enabled) }
                                }
                                // validation feedback
                                Rectangle {
                                    visible: !!kp.edit && !!kp.edit.check
                                    Layout.fillWidth: true
                                    implicitHeight: vcol.implicitHeight + 16
                                    radius: Theme.smallRadius
                                    readonly property bool okv: !!kp.edit && !!kp.edit.check && kp.edit.check.ok
                                    color: Qt.alpha(okv ? Theme.green : Theme.red, 0.12)
                                    ColumnLayout {
                                        id: vcol
                                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                        spacing: 4
                                        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.family: Theme.font; font.pixelSize: Theme.fontSm
                                               color: parent.parent.okv ? Theme.green : Theme.red
                                               text: !kp.edit || !kp.edit.check ? "" : (kp.edit.check.ok ? "Looks good" + (kp.edit.check.preview ? " · runs " + kp.edit.check.preview : "") : kp.edit.check.error) }
                                        Repeater {
                                            model: kp.edit && kp.edit.check ? kp.edit.check.warnings : []
                                            delegate: Text { required property string modelData; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "⚠ " + modelData; color: Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSm }
                                        }
                                        SettingRow {
                                            visible: !!kp.edit && !!kp.edit.check && kp.edit.check.warnings.length > 0 && kp.edit.kind === "command"
                                            title: "I understand what this command does"
                                            Toggle { checked: !!kp.edit && kp.edit.confirmed; accent: Theme.red; accessibleName: "Confirm"; onToggled: kp.setE("confirmed", !kp.edit.confirmed) }
                                        }
                                    }
                                }
                                RowLayout {
                                    spacing: 6
                                    UiBtn { label: "Save"; code: Theme.ic.save; selected: true; enabled: !kp.busy; onClicked: kp.saveCustom() }
                                    UiBtn { label: "Cancel"; onClicked: { kp.stopCapture(); kp.edit = null; kp.sel = null } }
                                    Item { Layout.fillWidth: true }
                                    UiBtn { visible: kp.edit && !kp.edit.isNew; label: "Delete"; code: Theme.ic.trash; danger: true; enabled: !kp.busy; onClicked: kp.deleteCustom(kp.edit.id) }
                                }
                            }
                        }
                    }
                }
            }

            // footer
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: kp.msg !== "" ? kp.msg : "Changes apply immediately (Hyprland reloads; a rejected change is rolled back)."
                    color: kp.msg === "" ? Theme.dim : (kp.bad ? Theme.red : (kp.busy ? Theme.muted : Theme.green))
                    font.family: Theme.font; font.pixelSize: Theme.fontSm
                }
                UiField { id: impField; implicitWidth: 200; placeholder: "~/Downloads/sleek-shell-keybinds-….json"; code: Theme.ic.importFile }
                UiBtn { label: "Import"; enabled: !kp.busy && impField.text.trim() !== ""; onClicked: { kp.busy = true; kp.msg = "Importing…"; saveP.command = ["python3", kp.tools, "import", impField.text]; saveP.running = true } }
                UiBtn { label: "Export"; code: Theme.ic.exportFile; enabled: !kp.busy; onClicked: { saveP.command = ["python3", kp.tools, "export"]; saveP.running = true } }
                UiBtn { label: "Restore defaults"; code: Theme.ic.restore; danger: true; enabled: !kp.busy
                        onClicked: { kp.busy = true; kp.msg = "Restoring built-in shortcuts…"; saveP.command = ["python3", kp.tools, "reset"]; saveP.running = true } }
            }
        }

        // recording overlay hint
        Rectangle {
            visible: kp.capturing
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 56 }
            width: hint.implicitWidth + 32; height: 40
            radius: 20
            color: Theme.accent
            Text { id: hint; anchors.centerIn: parent; text: "Press the new shortcut · Esc cancels"; color: Theme.onAccent; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold }
        }
    }
}
