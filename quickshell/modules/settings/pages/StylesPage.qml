import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components
import qs.modules.settings

SettingsPage {
    id: pg
    title: "Fonts, icons & cursors"
    subtitle: "Pick fonts for the shell, apps and terminal, and choose the cursor and application icon themes used by GTK, Qt, Hyprland and Rofi. Downloads stay in your home folder; repository packages are installed only after you confirm."

    property string tab: "fonts"
    readonly property int cols: width > 700 ? 2 : 1
    readonly property var catNames: ({ all: "All", sans: "Sans", serif: "Serif", hand: "Handwriting", display: "Display", mono: "Mono", imported: "Added" })
    function catColor(c) { return ({ sans: Theme.blue, serif: Theme.yellow, hand: Theme.pink, display: Theme.purple, mono: Theme.green, imported: Theme.cyan })[c] || Theme.muted }
    function hex(c) { return "#" + [c.r, c.g, c.b].map(function (v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2) }).join("") }
    function qtHas(f) { return Theme.fontList.indexOf(f) >= 0 }

    Component.onCompleted: { Settings.listDesktop(); StyleLibrary.ensureLoaded() }

    // ------------------------------------------------------------------ inline building blocks
    component ConfirmTrash: IconButton {
        id: ct
        property bool armed: false
        signal confirmed()
        code: armed ? Theme.ic.alert : Theme.ic.trash
        color: armed ? Theme.red : Theme.muted
        hoverColor: Theme.red
        tooltip: armed ? "Click again to remove" : "Remove"
        onClicked: { if (armed) { armed = false; confirmed() } else { armed = true; disarm.restart() } }
        Timer { id: disarm; interval: 3000; onTriggered: ct.armed = false }
    }
    component Card: Rectangle {
        property bool chosen: false
        property bool hovered: false
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        radius: Theme.controlRadius
        color: chosen ? Qt.alpha(Theme.accent, 0.16) : (hovered ? Theme.surfaceHi : Qt.alpha(Theme.text, 0.035))
        border.width: Theme.shellBorders ? (chosen ? 1.5 : 1) : 0
        border.color: chosen ? Theme.accent : Qt.alpha(Theme.text, 0.08)
    }
    component JobState: RowLayout {
        id: js
        property string kind: ""
        property string arg: ""
        property bool installed: false
        property string installLabel: "Install"
        property bool armed: false
        signal install()
        readonly property bool pending: StyleLibrary.isPending(kind, arg)
        readonly property bool running: StyleLibrary.current !== null && StyleLibrary.current.kind === kind && StyleLibrary.current.arg === arg
        spacing: 6
        Timer { id: jsDisarm; interval: 4000; onTriggered: js.armed = false }
        Badge { visible: js.installed && !js.pending; text: "Installed"; tone: Theme.green }
        Badge { visible: js.pending; text: js.running ? "Working..." : "Queued"; tone: Theme.yellow }
        UiBtn {
            visible: !js.installed && !js.pending
            label: js.armed ? "Confirm download" : js.installLabel
            selected: js.armed
            code: Theme.ic.download
            onClicked: {
                if (js.armed) { js.armed = false; js.install() }
                else { js.armed = true; jsDisarm.restart() }
            }
        }
    }
    component ChipRow: Flow {
        id: chips
        property var options: []        // [{ id, label }]
        property string current: ""
        signal picked(string optionId)
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: chips.options
            delegate: UiBtn {
                required property var modelData
                label: modelData.label
                selected: chips.current === modelData.id
                onClicked: chips.picked(modelData.id)
            }
        }
    }
    component AddOwn: SettingsSection {
        id: ao
        property string what: ""
        property string folder: ""
        property string folderLabel: "Open folder"
        title: "Add your own"
        subtitle: "Paste a path or a download link to " + what + ". Archives (.zip, .tar.gz, .tar.xz ...) and folders are scanned: fonts, icon themes and cursor themes are each put in the right place."
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            UiField { id: own; Layout.fillWidth: true; code: Theme.ic.link; placeholder: "~/Downloads/something.zip  or  https://..."; onAccepted: { StyleLibrary.installPath(text); text = "" } }
            UiBtn { label: "Add"; code: Theme.ic.plus; selected: true; onClicked: { StyleLibrary.installPath(own.text); own.text = "" } }
            UiBtn { visible: ao.folder !== ""; label: ao.folderLabel; code: Theme.ic.folder; onClicked: StyleLibrary.openFolder(ao.folder) }
        }
    }

    // ------------------------------------------------------------------ progress + starter pack
    SettingsSection {
        visible: StyleLibrary.busy || StyleLibrary.message !== ""
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Glyph { code: StyleLibrary.busy ? Theme.ic.download : (StyleLibrary.messageError ? Theme.ic.alert : Theme.ic.check); color: StyleLibrary.messageError && !StyleLibrary.busy ? Theme.red : Theme.accent; size: 18 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    Layout.fillWidth: true
                    text: StyleLibrary.busy ? "Installing " + StyleLibrary.current.label + (StyleLibrary.totalCount > 1 ? "  (" + (StyleLibrary.doneCount + 1) + " of " + StyleLibrary.totalCount + ")" : "") : StyleLibrary.message
                    color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; wrapMode: Text.WordWrap
                }
                Text {
                    visible: StyleLibrary.busy && StyleLibrary.message !== ""
                    Layout.fillWidth: true
                    text: StyleLibrary.message
                    color: StyleLibrary.messageError ? Theme.red : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; elide: Text.ElideRight
                }
                Rectangle {
                    visible: StyleLibrary.busy && StyleLibrary.totalCount > 1
                    Layout.fillWidth: true
                    implicitHeight: 4; radius: 2
                    color: Qt.alpha(Theme.text, 0.1)
                    Rectangle { width: parent.width * StyleLibrary.progress; height: parent.height; radius: 2; color: Theme.accent; Behavior on width { enabled: Theme.animations; NumberAnimation { duration: Theme.durBase } } }
                }
            }
            UiBtn { visible: StyleLibrary.busy && StyleLibrary.queue.length > 0; label: "Stop after this"; onClicked: StyleLibrary.cancelQueue() }
            IconButton { visible: !StyleLibrary.busy; code: Theme.ic.close; tooltip: "Dismiss"; onClicked: StyleLibrary.message = "" }
        }
    }

    SettingsSection {
        id: starterSec
        readonly property var missing: StyleLibrary.loaded ? StyleLibrary.starterMissing() : []
        title: "Variety pack"
        subtitle: StyleLibrary.starter.fonts.length + " fonts (handwriting, serif, display, sans and coding fonts), " + StyleLibrary.starter.icons.length + " icon themes and " + StyleLibrary.starter.cursors.length + " cursor themes, picked to give you lots of different looks."
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: !StyleLibrary.loaded ? (StyleLibrary.catalogError !== "" ? StyleLibrary.catalogError : "Loading the catalogue...")
                    : starterSec.missing.length === 0 ? "Everything in the pack is installed." : starterSec.missing.length + " items still to download"
                color: StyleLibrary.catalogError !== "" ? Theme.red : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap
            }
            UiBtn { visible: StyleLibrary.catalogError !== ""; label: "Retry"; code: Theme.ic.refresh; onClicked: StyleLibrary.load(true) }
            UiBtn {
                enabled: StyleLibrary.loaded && starterSec.missing.length > 0
                label: starterSec.missing.length > 0 ? "Install variety pack" : "Installed"
                code: starterSec.missing.length > 0 ? Theme.ic.pack : Theme.ic.check
                selected: starterSec.missing.length > 0
                onClicked: StyleLibrary.installStarter()
            }
        }
        Text {
            visible: StyleLibrary.loaded && starterSec.missing.some(function (j) { return j.kind === "icon" })
            Layout.fillWidth: true
            text: "Some icon themes are installed by running their own install.sh from GitHub (the authors' official installer); it only writes to ~/.local/share/icons."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontXs; wrapMode: Text.WordWrap
        }
    }

    Segment {
        Layout.fillWidth: true
        model: [{ id: "fonts", label: "Fonts", code: Theme.ic.font }, { id: "cursors", label: "Cursor themes", code: Theme.ic.cursor }, { id: "icons", label: "Application icons", code: Theme.ic.apps }]
        current: pg.tab
        onPicked: optionId => pg.tab = optionId
    }

    Text {
        Layout.fillWidth: true
        visible: Settings.desktopApplying || Settings.desktopMsg !== ""
        text: Settings.desktopApplying ? "Applying..." : Settings.desktopMsg
        color: Settings.desktopMsg.indexOf("Partly") === 0 || Settings.desktopMsg.indexOf("not installed") >= 0 ? Theme.red : Theme.accent
        font.family: Theme.font; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap
    }

    // ================================================================== FONTS
    SettingsSection {
        id: yours
        visible: pg.tab === "fonts"
        title: "Your fonts"
        subtitle: "Use any installed font for the shell, for apps (GTK, Qt, Rofi) or for the terminal (monospace fonts)."
        property string cat: "all"
        property string query: ""
        property int limit: 12
        readonly property var all: Settings.desktopInfo.library || []
        readonly property var shown: all.filter(function (x) {
            return (cat === "all" || x.c === cat || (cat === "imported" && x.user)) && (query === "" || x.f.toLowerCase().indexOf(query.toLowerCase()) >= 0)
        }).sort(function (a, b) { return (b.user - a.user) || a.f.localeCompare(b.f) })
        onCatChanged: limit = 12
        onQueryChanged: limit = 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            UiField { Layout.fillWidth: true; code: Theme.ic.search; placeholder: "Filter installed fonts"; onEdited: yours.query = text }
        }
        ChipRow {
            current: yours.cat
            options: ["all", "sans", "serif", "hand", "display", "mono"].map(function (c) {
                var n = c === "all" ? yours.all.length : yours.all.filter(function (x) { return x.c === c }).length
                return { id: c, label: pg.catNames[c] + "  " + n }
            }).concat([{ id: "imported", label: "Downloaded  " + yours.all.filter(function (x) { return x.user }).length }])
            onPicked: optionId => yours.cat = optionId
        }
        Text {
            visible: Settings.desktopListing && yours.all.length === 0
            text: "Scanning installed fonts..."
            color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
        GridLayout {
            Layout.fillWidth: true
            columns: pg.cols
            columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: yours.shown.slice(0, yours.limit)
                delegate: Card {
                    id: fc
                    required property var modelData
                    readonly property string fam: modelData.f
                    readonly property bool forShell: Theme.font === fam
                    readonly property bool forApps: Settings.appFont === fam
                    readonly property bool forTerm: Settings.monoFont === fam
                    chosen: forShell || forApps || forTerm
                    hovered: fcHover.hovered
                    implicitHeight: fcCol.implicitHeight + 20
                    HoverHandler { id: fcHover }
                    ColumnLayout {
                        id: fcCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { Layout.fillWidth: true; text: fc.fam; color: Theme.text; font.family: fc.fam; font.pixelSize: 22; elide: Text.ElideRight }
                            ConfirmTrash { visible: fc.modelData.user && !fc.chosen; onConfirmed: StyleLibrary.remove("font", fc.fam) }
                        }
                        Text { Layout.fillWidth: true; text: fc.modelData.c === "mono" ? "fn main() { let x = 0x1F; }  il1| O0" : "The quick brown fox jumps over the lazy dog"; color: Theme.muted; font.family: fc.fam; font.pixelSize: 13; elide: Text.ElideRight }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Badge { text: pg.catNames[fc.modelData.c] || fc.modelData.c; tone: pg.catColor(fc.modelData.c) }
                            Badge { visible: fc.modelData.user; text: "Downloaded"; tone: Theme.cyan }
                            Item { Layout.fillWidth: true }
                            UiBtn { label: "Shell"; selected: fc.forShell; onClicked: Theme.set("fontFamily", fc.fam) }
                            UiBtn { label: "Apps"; selected: fc.forApps; onClicked: Settings.setDesktop("appFont", fc.fam) }
                            UiBtn { visible: fc.modelData.c === "mono"; label: "Terminal"; selected: fc.forTerm; onClicked: Settings.setDesktop("monoFont", fc.fam) }
                        }
                    }
                }
            }
        }
        Text {
            visible: yours.shown.length === 0 && yours.all.length > 0
            text: "No installed fonts match. Try \"Get more fonts\" below."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
        UiBtn {
            visible: yours.shown.length > yours.limit
            Layout.alignment: Qt.AlignHCenter
            label: "Show more (" + (yours.shown.length - yours.limit) + " left)"
            code: Theme.ic.down
            onClicked: yours.limit += 24
        }
    }

    SettingsSection {
        id: tamilSec
        readonly property var tamil: Settings.desktopInfo.tamil || []
        visible: pg.tab === "fonts" && tamil.length > 0
        title: "Tamil-only fonts"
        subtitle: "These families identify themselves as Tamil-script faces. Removing them deletes their files instead of hiding them: your own fonts immediately, system fonts after the administrator prompt (moved to a backup folder, so a package update can still restore them)."
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: tamilSec.tamil.map(function (x) { return x.f }).join("  ·  ")
                color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap
            }
            ConfirmBtn {
                baseLabel: "Remove " + tamilSec.tamil.length + " families"
                confirmLabel: "Confirm removal"
                code: Theme.ic.trash
                enabled: !StyleLibrary.isPending("tamil", "tamil")
                onConfirmed: StyleLibrary.removeTamil()
            }
        }
        Text {
            visible: StyleLibrary.isPending("tamil", "tamil")
            Layout.fillWidth: true
            text: "Removing Tamil-only fonts... approve the administrator prompt if one appears."
            color: Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap
        }
    }

    SettingsSection {
        visible: pg.tab === "fonts"
        title: "Sizes and current choices"
        subtitle: "Shell: " + Theme.font + (Theme.fontFamily === "" ? " (automatic)" : "") + "   ·   Apps: " + Settings.appFont + "   ·   Terminal: " + Settings.monoFont
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { Layout.fillWidth: true; text: "Shell text follows the font you pick with \"Shell\". Icons always use JetBrainsMono Nerd Font."; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap }
            UiBtn { label: "Automatic shell font"; selected: Theme.fontFamily === ""; onClicked: Theme.set("fontFamily", "") }
        }
        LabeledSlider {
            label: "App font size"
            valueText: Settings.appFontSize + " pt"
            code: Theme.ic.font; accent: Theme.blue
            from: 0; value: (Settings.appFontSize - 7) * 100 / 17
            onMoved: v => Settings.setDesktop("appFontSize", 7 + Math.round(v * 17 / 100))
            onReset: Settings.setDesktop("appFontSize", Settings.defaults.appFontSize)
        }
        LabeledSlider {
            label: "Terminal font size"
            valueText: Settings.monoFontSize + " pt"
            code: Theme.ic.terminal; accent: Theme.green
            from: 0; value: (Settings.monoFontSize - 7) * 100 / 21
            onMoved: v => Settings.setDesktop("monoFontSize", 7 + Math.round(v * 21 / 100))
            onReset: Settings.setDesktop("monoFontSize", Settings.defaults.monoFontSize)
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                readonly property var c: Settings.desktopInfo.current || {}
                visible: !!c.gtkFont
                text: "Now in use: GTK " + (c.gtkFont || "?") + "    Qt " + ((c.qtFont || "default").split(",").slice(0, 2).join(" "))
                color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap
            }
            UiBtn { label: "Apply again"; code: Theme.ic.refresh; onClicked: Settings.applyDesktop() }
        }
    }

    SettingsSection {
        id: shop
        visible: pg.tab === "fonts"
        title: "Get more fonts"
        subtitle: "Free fonts from Google Fonts (" + StyleLibrary.fonts.length + " families). Each preview is drawn in the font itself; installing takes a few seconds."
        property string cat: "hand"
        property string query: ""
        property int limit: 24
        readonly property var shown: StyleLibrary.fonts.filter(function (x) {
            return (cat === "all" || x.c === cat) && (query === "" || x.f.toLowerCase().indexOf(query.toLowerCase()) >= 0)
        })
        readonly property var page: shown.slice(0, limit)
        onCatChanged: limit = 24
        onQueryChanged: limit = 24
        onPageChanged: previewT.restart()
        onVisibleChanged: if (visible) previewT.restart()
        Timer {
            id: previewT
            interval: 250
            onTriggered: if (shop.visible) StyleLibrary.requestPreviews(shop.page.filter(function (x) { return !x.i && !pg.qtHas(x.f) }).map(function (x) { return x.f }), pg.hex(Theme.text))
        }
        UiField { Layout.fillWidth: true; code: Theme.ic.search; placeholder: "Search Google Fonts, e.g. Caveat, Lora, Fira"; onEdited: shop.query = text }
        ChipRow {
            current: shop.cat
            options: ["all", "hand", "sans", "serif", "display", "mono"].map(function (c) {
                var n = c === "all" ? StyleLibrary.fonts.length : (StyleLibrary.fontCounts[c] || 0)
                return { id: c, label: pg.catNames[c] + "  " + n }
            })
            onPicked: optionId => shop.cat = optionId
        }
        Text {
            visible: !StyleLibrary.loaded
            text: StyleLibrary.catalogError !== "" ? StyleLibrary.catalogError : "Loading Google Fonts..."
            color: StyleLibrary.catalogError !== "" ? Theme.red : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
        GridLayout {
            Layout.fillWidth: true
            columns: pg.cols
            columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: shop.page
                delegate: Card {
                    id: gfc
                    required property var modelData
                    readonly property string fam: modelData.f
                    readonly property bool live: modelData.i || pg.qtHas(fam)
                    readonly property var png: StyleLibrary.preview(fam)
                    hovered: gcHover.hovered
                    implicitHeight: 88
                    HoverHandler { id: gcHover }
                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 6
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            clip: true
                            Text { visible: gfc.live; anchors.verticalCenter: parent.verticalCenter; width: parent.width; text: gfc.fam; color: Theme.text; font.family: gfc.fam; font.pixelSize: 24; elide: Text.ElideRight }
                            Image {
                                visible: !gfc.live && !!gfc.png
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                height: 28; width: Math.min(parent.width, implicitWidth * 28 / Math.max(1, implicitHeight))
                                source: gfc.png ? "file://" + gfc.png : ""
                                fillMode: Image.PreserveAspectFit; horizontalAlignment: Image.AlignLeft
                                asynchronous: true; smooth: true; mipmap: true
                            }
                            Text {
                                visible: !gfc.live && !gfc.png
                                anchors.verticalCenter: parent.verticalCenter
                                text: gfc.png === undefined ? "Loading preview..." : "No preview"
                                color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: gfc.fam; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; elide: Text.ElideRight; Layout.maximumWidth: 150 }
                            Badge { text: pg.catNames[gfc.modelData.c] || gfc.modelData.c; tone: pg.catColor(gfc.modelData.c) }
                            Badge { visible: gfc.modelData.s > 1; text: gfc.modelData.s + " styles"; tone: Theme.muted }
                            Item { Layout.fillWidth: true }
                            JobState { kind: "font"; arg: gfc.fam; installed: gfc.live; onInstall: StyleLibrary.installFont(gfc.fam) }
                        }
                    }
                }
            }
        }
        Text {
            visible: StyleLibrary.loaded && shop.shown.length === 0
            text: "No fonts match \"" + shop.query + "\"."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { Layout.fillWidth: true; visible: shop.shown.length > 0; text: "Showing " + shop.page.length + " of " + shop.shown.length + ", most popular first"; color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontXs }
            UiBtn { visible: shop.shown.length > shop.limit; label: "Show more"; code: Theme.ic.down; onClicked: shop.limit += 24 }
            UiBtn { label: "Refresh list"; code: Theme.ic.refresh; onClicked: StyleLibrary.load(true) }
        }
    }

    AddOwn { visible: pg.tab === "fonts"; what: ".ttf / .otf font files, a zip of fonts or a folder"; folder: StyleLibrary.dirs.fonts || (Quickshell.env("HOME") + "/.local/share/fonts"); folderLabel: "Open fonts folder" }

    // ================================================================== ICONS
    SettingsSection {
        id: iconCurrent
        visible: pg.tab === "icons"
        title: "Current application icon theme"
        subtitle: "One theme is shared by GTK apps, KDE/Qt apps and Rofi. Some already-open applications keep their old icons until restarted."
        readonly property var cur: (Settings.desktopInfo.icons || []).filter(function (x) { return x.id === Settings.iconTheme })[0] || null
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                implicitWidth: 40; implicitHeight: 40; radius: Theme.controlRadius
                color: Qt.alpha(Theme.accent, 0.18); border.width: 1; border.color: Qt.alpha(Theme.accent, 0.5)
                Glyph { anchors.centerIn: parent; code: Theme.ic.apps; size: 20; color: Theme.accent }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: Settings.iconTheme || "Automatic"; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                Text {
                    Layout.fillWidth: true
                    text: iconCurrent.cur ? (iconCurrent.cur.comment || "Installed icon theme") : "Selected theme; waiting for the icon list to refresh"
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; elide: Text.ElideRight
                }
            }
            Badge { text: iconCurrent.cur ? (iconCurrent.cur.removable ? "User theme" : "System theme") : "Selected"; tone: Theme.cyan }
            UiBtn { label: "Apply again"; code: Theme.ic.refresh; onClicked: Settings.applyDesktop() }
        }
        Text {
            Layout.fillWidth: true
            text: "Integration: GTK and Rofi are updated immediately. KDE/Qt reads kdeglobals [Icons] Theme; only compatible Qt styles and apps that honour the KDE setting will change, usually after a restart. XWayland apps use the Xcursor environment rather than the icon theme."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontXs; wrapMode: Text.WordWrap
        }
    }

    SettingsSection {
        id: iconInstalled
        visible: pg.tab === "icons"
        title: "Installed icon themes"
        subtitle: "Discovered from your home folder and the system icon directories. Click a card to use it everywhere icons are applied."
        property string query: ""
        readonly property var all: Settings.desktopInfo.icons || []
        readonly property var shown: all.filter(function (x) {
            return query === "" || (x.name || "").toLowerCase().indexOf(query.toLowerCase()) >= 0 || (x.id || "").toLowerCase().indexOf(query.toLowerCase()) >= 0
        })
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            UiField { Layout.fillWidth: true; code: Theme.ic.search; placeholder: "Search installed icon themes"; onEdited: iconInstalled.query = text }
            UiBtn { visible: Settings.desktopListing; label: "Refresh"; code: Theme.ic.refresh; onClicked: Settings.listDesktop() }
        }
        Text {
            visible: Settings.desktopListing && iconInstalled.all.length === 0
            text: "Scanning installed icon themes..."
            color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
        Text {
            visible: !Settings.desktopListing && iconInstalled.all.length === 0
            text: "No icon themes were found. Use \"Get more icon themes\" below."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
        Text {
            visible: iconInstalled.all.length > 0 && iconInstalled.shown.length === 0
            text: "No installed icon themes match \"" + iconInstalled.query + "\"."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
        GridLayout {
            Layout.fillWidth: true
            columns: pg.cols
            columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: iconInstalled.shown
                delegate: Card {
                    id: card
                    required property var modelData
                    chosen: Settings.iconTheme === modelData.id
                    hovered: cardMa.containsMouse
                    implicitHeight: 74
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: "Icon theme " + modelData.name
                    Accessible.checked: chosen
                    MouseArea { id: cardMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Settings.setDesktop("iconTheme", card.modelData.id) }
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 10
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: card.modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: card.chosen ? Font.DemiBold : Font.Normal; Layout.fillWidth: true; elide: Text.ElideRight }
                            Glyph { visible: card.chosen; code: Theme.ic.check; color: Theme.accent; size: Theme.fontMd }
                            ConfirmTrash { visible: card.modelData.removable && !card.chosen; boxSize: 22; onConfirmed: StyleLibrary.remove("icon", card.modelData.id) }
                        }
                        Row {
                            spacing: 8
                            Repeater {
                                model: ["folder", "home", "terminal", "files", "browser", "settings", "text", "image"]
                                delegate: Image {
                                    required property string modelData
                                    readonly property string src: card.modelData.preview[modelData] || ""
                                    visible: src !== ""
                                    width: 24; height: 24
                                    sourceSize: Qt.size(48, 48)
                                    source: src !== "" ? "file://" + src : ""
                                    asynchronous: true; smooth: true; mipmap: true
                                    fillMode: Image.PreserveAspectFit
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsSection {
        id: iconShop
        visible: pg.tab === "icons"
        title: "Get more icon themes"
        subtitle: "Popular free icon themes. Downloads go to ~/.local/share/icons. Repository packages need your confirmation and a polkit password prompt; nothing is installed automatically."
        property string query: ""
        property string filter: "available"
        readonly property var all: StyleLibrary.icons
        readonly property var matching: all.filter(function (x) {
            return query === "" || (x.name || "").toLowerCase().indexOf(query.toLowerCase()) >= 0 || (x.desc || "").toLowerCase().indexOf(query.toLowerCase()) >= 0
        })
        readonly property var available: matching.filter(function (x) { return !x.installed })
        readonly property var installed: matching.filter(function (x) { return x.installed })
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            UiField { Layout.fillWidth: true; code: Theme.ic.search; placeholder: "Search icon themes, e.g. Papirus, Tela, Fluent"; onEdited: iconShop.query = text }
            UiBtn { label: "Refresh list"; code: Theme.ic.refresh; onClicked: StyleLibrary.load(true) }
        }
        ChipRow {
            current: iconShop.filter
            options: [
                { id: "available", label: "Available  " + iconShop.available.length },
                { id: "installed", label: "Installed  " + iconShop.installed.length },
                { id: "all", label: "All  " + iconShop.matching.length }
            ]
            onPicked: optionId => iconShop.filter = optionId
        }
        Text {
            visible: !StyleLibrary.loaded
            text: StyleLibrary.catalogError !== "" ? StyleLibrary.catalogError : "Loading the icon catalogue..."
            color: StyleLibrary.catalogError !== "" ? Theme.red : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
        UiBtn { visible: StyleLibrary.catalogError !== ""; label: "Retry"; code: Theme.ic.refresh; onClicked: StyleLibrary.load(true) }
        Text {
            visible: StyleLibrary.loaded && StyleLibrary.platform.canInstallPackages === false
            Layout.fillWidth: true
            text: "Repository installation is unavailable on this system (needs Arch/CachyOS, pacman and pkexec). Downloads still work."
            color: Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontXs; wrapMode: Text.WordWrap
        }

        Text {
            visible: iconShop.filter !== "installed" && iconShop.available.length > 0
            text: "Available to install"
            color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold
        }
        GridLayout {
            visible: iconShop.filter !== "installed"
            Layout.fillWidth: true
            columns: pg.cols
            columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: iconShop.available
                delegate: Card {
                    id: ic
                    required property var modelData
                    readonly property bool pkgPending: StyleLibrary.isPending("pkg", modelData.id)
                    readonly property bool dlPending: StyleLibrary.isPending("icon", modelData.id)
                    implicitHeight: icCol.implicitHeight + 20
                    ColumnLayout {
                        id: icCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle { implicitWidth: 10; implicitHeight: 10; radius: 5; color: Theme[ic.modelData.tone] || Theme.accent }
                            Text { Layout.fillWidth: true; text: ic.modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text { text: "~" + ic.modelData.mb + " MB"; color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontXs }
                        }
                        Text { Layout.fillWidth: true; text: ic.modelData.desc; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Badge { visible: ic.modelData.script; text: "official install.sh"; tone: Theme.muted }
                            Badge { visible: ic.modelData.pkg !== "" && ic.modelData.pkgAvailable; text: "repository package"; tone: Theme.green }
                            Badge { visible: ic.modelData.pkg !== "" && !ic.modelData.pkgAvailable; text: "package unavailable"; tone: Theme.yellow }
                            Badge { visible: ic.pkgPending; text: StyleLibrary.current && StyleLibrary.current.arg === ic.modelData.id ? "Installing package..." : "Queued"; tone: Theme.yellow }
                            Badge { visible: ic.dlPending; text: "Downloading..."; tone: Theme.yellow }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Item { Layout.fillWidth: true }
                            ConfirmBtn {
                                visible: !!ic.modelData.pkg && ic.modelData.pkgAvailable && StyleLibrary.platform.canInstallPackages && !ic.pkgPending && !ic.dlPending
                                baseLabel: "Install package"
                                confirmLabel: "Confirm package install"
                                code: Theme.ic.pack
                                onConfirmed: StyleLibrary.installPackage(ic.modelData, "icon")
                            }
                            ConfirmBtn {
                                visible: ic.modelData.downloadable && !ic.pkgPending && !ic.dlPending
                                baseLabel: "Download"
                                confirmLabel: "Confirm download"
                                code: Theme.ic.download
                                onConfirmed: StyleLibrary.installIcon(ic.modelData)
                            }
                            Badge {
                                visible: !ic.modelData.downloadable && !(!!ic.modelData.pkg && ic.modelData.pkgAvailable)
                                text: "Not available here"; tone: Theme.red
                            }
                        }
                    }
                }
            }
        }
        Text {
            visible: StyleLibrary.loaded && iconShop.filter === "available" && iconShop.available.length === 0
            text: iconShop.matching.length === 0 ? "No icon themes match \"" + iconShop.query + "\"." : "Every matching icon theme is already installed."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }

        Text {
            visible: iconShop.filter !== "available" && iconShop.installed.length > 0
            text: "Installed from the store"
            color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold
        }
        GridLayout {
            visible: iconShop.filter !== "available"
            Layout.fillWidth: true
            columns: pg.cols
            columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: iconShop.installed
                delegate: Card {
                    id: icg
                    required property var modelData
                    readonly property bool inUse: (modelData.themes || []).indexOf(Settings.iconTheme) >= 0
                    chosen: icg.inUse
                    implicitHeight: icgCol.implicitHeight + 20
                    ColumnLayout {
                        id: icgCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle { implicitWidth: 10; implicitHeight: 10; radius: 5; color: Theme[icg.modelData.tone] || Theme.accent }
                            Text { Layout.fillWidth: true; text: icg.modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Badge { text: icg.inUse ? "In use" : "Installed"; tone: icg.inUse ? Theme.green : Theme.muted }
                            ConfirmTrash { visible: !!icg.modelData.downloaded && !icg.inUse; boxSize: 22; onConfirmed: StyleLibrary.removeThemes("icon", icg.modelData.themes) }
                        }
                        Text { Layout.fillWidth: true; text: (icg.modelData.themes || []).join(", "); color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; elide: Text.ElideRight }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: icg.modelData.themes || []
                                delegate: UiBtn {
                                    required property string modelData
                                    label: modelData
                                    selected: Settings.iconTheme === modelData
                                    onClicked: Settings.setDesktop("iconTheme", modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    AddOwn { visible: pg.tab === "icons"; what: "an icon theme (for example from gnome-look.org or a GitHub release)"; folder: StyleLibrary.dirs.icons || (Quickshell.env("HOME") + "/.local/share/icons"); folderLabel: "Open icons folder" }

    // ================================================================== CURSORS
    SettingsSection {
        id: cursorCurrent
        visible: pg.tab === "cursors"
        title: "Current cursor theme"
        subtitle: "Applied immediately in Hyprland and written for GTK, KDE/Qt and XWayland. New windows pick it up at once; already-open apps may need a restart."
        readonly property var cur: (Settings.desktopInfo.cursors || []).filter(function (x) { return x.id === Settings.cursorTheme })[0] || null
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                implicitWidth: 40; implicitHeight: 40; radius: Theme.controlRadius
                color: Qt.alpha(Theme.accent, 0.18); border.width: 1; border.color: Qt.alpha(Theme.accent, 0.5)
                Glyph { anchors.centerIn: parent; code: Theme.ic.cursor; size: 20; color: Theme.accent }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: Settings.cursorTheme || "System default"; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                Text {
                    Layout.fillWidth: true
                    text: Settings.cursorSize + " px" + (Settings.desktopInfo.current && Settings.desktopInfo.current.cursorSize ? "  ·  now " + Settings.desktopInfo.current.cursorSize + " px" : "")
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm
                }
            }
            Badge { text: cursorCurrent.cur ? (cursorCurrent.cur.removable ? "User theme" : "System theme") : "Selected"; tone: Theme.cyan }
            UiBtn { label: "Apply again"; code: Theme.ic.refresh; onClicked: Settings.applyDesktop() }
        }
        LabeledSlider {
            label: "Cursor size"
            valueText: Settings.cursorSize + " px"
            code: Theme.ic.cursor; accent: Theme.cyan
            from: 0; value: (Settings.cursorSize - 16) * 100 / 48
            onMoved: v => Settings.setDesktop("cursorSize", 16 + Math.round(v * 48 / 100))
            onReset: Settings.setDesktop("cursorSize", Settings.defaults.cursorSize)
        }
        Text {
            Layout.fillWidth: true
            text: "Integration: Hyprland (hyprctl setcursor and HYPRCURSOR_*), XCURSOR_THEME / XCURSOR_SIZE for XWayland, GTK 3/4 (gsettings and settings.ini) and KDE/Qt (kcminputrc). Cursor size is saved in settings.json and written to hypr-cursor.lua so it survives reboot."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontXs; wrapMode: Text.WordWrap
        }
    }

    SettingsSection {
        id: cursorInstalled
        visible: pg.tab === "cursors"
        title: "Installed cursor themes"
        subtitle: "Discovered from ~/.local/share/icons and the system icon directories. Click a card to apply it."
        property string query: ""
        readonly property var all: Settings.desktopInfo.cursors || []
        readonly property var shown: all.filter(function (x) {
            return query === "" || (x.name || "").toLowerCase().indexOf(query.toLowerCase()) >= 0 || (x.id || "").toLowerCase().indexOf(query.toLowerCase()) >= 0
        })
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            UiField { Layout.fillWidth: true; code: Theme.ic.search; placeholder: "Search installed cursor themes"; onEdited: cursorInstalled.query = text }
            UiBtn { visible: Settings.desktopListing; label: "Refresh"; code: Theme.ic.refresh; onClicked: Settings.listDesktop() }
        }
        Text {
            visible: Settings.desktopListing && cursorInstalled.all.length === 0
            text: "Scanning installed cursor themes..."
            color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
        Text {
            visible: !Settings.desktopListing && cursorInstalled.all.length === 0
            text: "No cursor themes were found. Use \"Get more cursor themes\" below."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
        Text {
            visible: cursorInstalled.all.length > 0 && cursorInstalled.shown.length === 0
            text: "No installed cursor themes match \"" + cursorInstalled.query + "\"."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
        GridLayout {
            Layout.fillWidth: true
            columns: pg.cols
            columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: cursorInstalled.shown
                delegate: Card {
                    id: cc
                    required property var modelData
                    chosen: Settings.cursorTheme === modelData.id
                    hovered: ccMa.containsMouse
                    implicitHeight: 84
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: "Cursor theme " + modelData.name
                    Accessible.checked: chosen
                    MouseArea { id: ccMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Settings.setDesktop("cursorTheme", cc.modelData.id) }
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 10
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: cc.modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: cc.chosen ? Font.DemiBold : Font.Normal; Layout.fillWidth: true; elide: Text.ElideRight }
                            Glyph { visible: cc.chosen; code: Theme.ic.check; color: Theme.accent; size: Theme.fontMd }
                            ConfirmTrash { visible: cc.modelData.removable && !cc.chosen; boxSize: 22; onConfirmed: StyleLibrary.remove("cursor", cc.modelData.id) }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: Theme.controlRadius - 2
                            color: Qt.alpha(Theme.text, 0.06)
                            Row {
                                anchors.centerIn: parent
                                spacing: 18
                                Repeater {
                                    model: ["pointer", "hand", "text", "wait"]
                                    delegate: Image {
                                        required property string modelData
                                        readonly property string src: cc.modelData.preview[modelData] || ""
                                        visible: src !== ""
                                        width: 28; height: 28
                                        source: src !== "" ? "file://" + src : ""
                                        asynchronous: true; smooth: true; mipmap: true
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsSection {
        id: cursorShop
        visible: pg.tab === "cursors"
        title: "Get more cursor themes"
        subtitle: "Bibata, Breeze, Adwaita, Nordzy, Capitaine, Qogir and more. Downloads stay in ~/.local/share/icons; repository packages are installed only after confirmation."
        property string query: ""
        property string filter: "available"
        readonly property var all: StyleLibrary.cursors
        readonly property var matching: all.filter(function (x) {
            return query === "" || (x.name || "").toLowerCase().indexOf(query.toLowerCase()) >= 0 || (x.desc || "").toLowerCase().indexOf(query.toLowerCase()) >= 0
        })
        readonly property var available: matching.filter(function (x) { return !x.installed })
        readonly property var installed: matching.filter(function (x) { return x.installed })
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            UiField { Layout.fillWidth: true; code: Theme.ic.search; placeholder: "Search cursor themes, e.g. Bibata, Nordzy, Qogir"; onEdited: cursorShop.query = text }
            UiBtn { label: "Refresh list"; code: Theme.ic.refresh; onClicked: StyleLibrary.load(true) }
        }
        ChipRow {
            current: cursorShop.filter
            options: [
                { id: "available", label: "Available  " + cursorShop.available.length },
                { id: "installed", label: "Installed  " + cursorShop.installed.length },
                { id: "all", label: "All  " + cursorShop.matching.length }
            ]
            onPicked: optionId => cursorShop.filter = optionId
        }
        Text {
            visible: !StyleLibrary.loaded
            text: StyleLibrary.catalogError !== "" ? StyleLibrary.catalogError : "Loading the cursor catalogue..."
            color: StyleLibrary.catalogError !== "" ? Theme.red : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
        UiBtn { visible: StyleLibrary.catalogError !== ""; label: "Retry"; code: Theme.ic.refresh; onClicked: StyleLibrary.load(true) }
        Text {
            visible: StyleLibrary.loaded && StyleLibrary.platform.canInstallPackages === false
            Layout.fillWidth: true
            text: "Repository installation is unavailable on this system (needs Arch/CachyOS, pacman and pkexec). Downloads still work."
            color: Theme.yellow; font.family: Theme.font; font.pixelSize: Theme.fontXs; wrapMode: Text.WordWrap
        }

        Text {
            visible: cursorShop.filter !== "installed" && cursorShop.available.length > 0
            text: "Available to install"
            color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold
        }
        GridLayout {
            visible: cursorShop.filter !== "installed"
            Layout.fillWidth: true
            columns: pg.cols
            columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: cursorShop.available
                delegate: Card {
                    id: cu
                    required property var modelData
                    readonly property bool pkgPending: StyleLibrary.isPending("pkg", modelData.id)
                    readonly property bool dlPending: StyleLibrary.isPending("cursor", modelData.id)
                    implicitHeight: cuCol.implicitHeight + 20
                    ColumnLayout {
                        id: cuCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Rectangle {
                                implicitWidth: 30; implicitHeight: 30; radius: 15
                                color: cu.modelData.tone
                                border.width: 1; border.color: Qt.alpha(Theme.text, 0.25)
                                Glyph { anchors.centerIn: parent; code: Theme.ic.cursor; size: 16; color: Qt.color(cu.modelData.tone).hslLightness > 0.6 ? "#111111" : "#f5f5f5" }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text { Layout.fillWidth: true; text: cu.modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { Layout.fillWidth: true; text: cu.modelData.desc; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; elide: Text.ElideRight }
                            }
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Badge { visible: cu.modelData.pkg !== "" && cu.modelData.pkgAvailable; text: "repository package"; tone: Theme.green }
                            Badge { visible: cu.modelData.pkg !== "" && !cu.modelData.pkgAvailable; text: "package unavailable"; tone: Theme.yellow }
                            Badge { visible: cu.pkgPending; text: "Installing package..."; tone: Theme.yellow }
                            Badge { visible: cu.dlPending; text: "Downloading..."; tone: Theme.yellow }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Item { Layout.fillWidth: true }
                            ConfirmBtn {
                                visible: !!cu.modelData.pkg && cu.modelData.pkgAvailable && StyleLibrary.platform.canInstallPackages && !cu.pkgPending && !cu.dlPending
                                baseLabel: "Install package"
                                confirmLabel: "Confirm package install"
                                code: Theme.ic.pack
                                onConfirmed: StyleLibrary.installPackage(cu.modelData, "cursor")
                            }
                            ConfirmBtn {
                                visible: cu.modelData.downloadable && !cu.pkgPending && !cu.dlPending
                                baseLabel: "Download"
                                confirmLabel: "Confirm download"
                                code: Theme.ic.download
                                onConfirmed: StyleLibrary.installCursor(cu.modelData)
                            }
                            Badge {
                                visible: !cu.modelData.downloadable && !(!!cu.modelData.pkg && cu.modelData.pkgAvailable)
                                text: "Not available here"; tone: Theme.red
                            }
                        }
                    }
                }
            }
        }
        Text {
            visible: StyleLibrary.loaded && cursorShop.filter === "available" && cursorShop.available.length === 0
            text: cursorShop.matching.length === 0 ? "No cursor themes match \"" + cursorShop.query + "\"." : "Every matching cursor theme is already installed."
            color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }

        Text {
            visible: cursorShop.filter !== "available" && cursorShop.installed.length > 0
            text: "Installed from the store"
            color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold
        }
        GridLayout {
            visible: cursorShop.filter !== "available"
            Layout.fillWidth: true
            columns: pg.cols
            columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: cursorShop.installed
                delegate: Card {
                    id: cug
                    required property var modelData
                    readonly property bool inUse: (modelData.themes || []).indexOf(Settings.cursorTheme) >= 0
                    chosen: cug.inUse
                    implicitHeight: cugCol.implicitHeight + 20
                    ColumnLayout {
                        id: cugCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                implicitWidth: 26; implicitHeight: 26; radius: 13
                                color: cug.modelData.tone
                                border.width: 1; border.color: Qt.alpha(Theme.text, 0.25)
                                Glyph { anchors.centerIn: parent; code: Theme.ic.cursor; size: 14; color: Qt.color(cug.modelData.tone).hslLightness > 0.6 ? "#111111" : "#f5f5f5" }
                            }
                            Text { Layout.fillWidth: true; text: cug.modelData.name; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Badge { text: cug.inUse ? "In use" : "Installed"; tone: cug.inUse ? Theme.green : Theme.muted }
                            ConfirmTrash { visible: !!cug.modelData.downloaded && !cug.inUse; boxSize: 22; onConfirmed: StyleLibrary.removeThemes("cursor", cug.modelData.themes) }
                        }
                        Text { Layout.fillWidth: true; text: (cug.modelData.themes || []).join(", "); color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm; elide: Text.ElideRight }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: cug.modelData.themes || []
                                delegate: UiBtn {
                                    required property string modelData
                                    label: modelData
                                    selected: Settings.cursorTheme === modelData
                                    onClicked: Settings.setDesktop("cursorTheme", modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    AddOwn { visible: pg.tab === "cursors"; what: "a cursor theme (a folder or archive with index.theme and a cursors/ folder)"; folder: StyleLibrary.dirs.icons || (Quickshell.env("HOME") + "/.local/share/icons"); folderLabel: "Open icons folder" }
}
