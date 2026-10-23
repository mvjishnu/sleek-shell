import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components
import qs.modules.settings

SettingsPage {
    id: pg
    title: "Fonts, icons & cursors"
    subtitle: "Download new fonts, app icon themes and mouse cursors, then pick them for the shell, your apps and the terminal. Everything installs into your home folder; no password needed."

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
        border.width: chosen ? 1.5 : 1
        border.color: chosen ? Theme.accent : Qt.alpha(Theme.text, 0.08)
    }
    component JobState: RowLayout {
        id: js
        property string kind: ""
        property string arg: ""
        property bool installed: false
        property string installLabel: "Install"
        signal install()
        readonly property bool pending: StyleLibrary.isPending(kind, arg)
        readonly property bool running: StyleLibrary.current !== null && StyleLibrary.current.kind === kind && StyleLibrary.current.arg === arg
        spacing: 6
        Badge { visible: js.installed && !js.pending; text: "Installed"; tone: Theme.green }
        Badge { visible: js.pending; text: js.running ? "Downloading..." : "Queued"; tone: Theme.yellow }
        UiBtn { visible: !js.installed && !js.pending; label: js.installLabel; code: Theme.ic.download; onClicked: js.install() }
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
        model: [{ id: "fonts", label: "Fonts", code: Theme.ic.font }, { id: "icons", label: "App icons", code: Theme.ic.apps }, { id: "cursors", label: "Mouse cursors", code: Theme.ic.cursor }]
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
        visible: pg.tab === "icons"
        title: "App icon themes"
        subtitle: "Click a theme to use it for apps, file managers and Rofi. Apps that are already open may need a restart."
        Text {
            visible: Settings.desktopListing && Settings.desktopInfo.icons.length === 0
            text: "Scanning installed themes..."
            color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
        GridLayout {
            Layout.fillWidth: true
            columns: pg.cols
            columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: Settings.desktopInfo.icons
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
        visible: pg.tab === "icons"
        title: "Get more icon themes"
        subtitle: "Popular free icon themes. Sizes are approximate downloads."
        GridLayout {
            Layout.fillWidth: true
            columns: pg.cols
            columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: StyleLibrary.icons
                delegate: Card {
                    id: ic
                    required property var modelData
                    chosen: modelData.installed && modelData.themes.indexOf(Settings.iconTheme) >= 0
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
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Badge { visible: ic.modelData.script; text: "official install.sh"; tone: Theme.muted }
                            Item { Layout.fillWidth: true }
                            UiBtn {
                                visible: ic.modelData.installed && ic.modelData.themes.length > 0
                                label: ic.chosen ? "In use" : "Use"
                                selected: ic.chosen
                                onClicked: Settings.setDesktop("iconTheme", ic.modelData.themes[0])
                            }
                            JobState { kind: "icon"; arg: ic.modelData.id; installed: ic.modelData.installed; onInstall: StyleLibrary.installIcon(ic.modelData) }
                        }
                    }
                }
            }
        }
        Text {
            visible: !StyleLibrary.loaded
            text: StyleLibrary.catalogError !== "" ? StyleLibrary.catalogError : "Loading the catalogue..."
            color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
    }

    AddOwn { visible: pg.tab === "icons"; what: "an icon theme (for example from gnome-look.org or a GitHub release)"; folder: StyleLibrary.dirs.icons || (Quickshell.env("HOME") + "/.local/share/icons"); folderLabel: "Open icons folder" }

    // ================================================================== CURSORS
    SettingsSection {
        visible: pg.tab === "cursors"
        title: "Mouse cursor"
        subtitle: "Applies to Hyprland right away and to GTK / Qt apps (new windows; some already-open apps keep the old cursor until restarted)."
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text { text: "Size"; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold }
            Segment {
                Layout.fillWidth: true
                model: Settings.cursorSizes.map(function (s) { return { id: String(s), label: s + " px", code: 0 } })
                current: String(Settings.cursorSize)
                onPicked: optionId => Settings.setDesktop("cursorSize", Number(optionId))
            }
        }
        Text {
            visible: Settings.desktopListing && (Settings.desktopInfo.cursors || []).length === 0
            text: "Scanning installed cursors..."
            color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm
        }
        GridLayout {
            Layout.fillWidth: true
            columns: pg.cols
            columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: Settings.desktopInfo.cursors || []
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
        visible: pg.tab === "cursors"
        title: "Get more cursors"
        subtitle: "Free cursor themes, ready to use after a quick download."
        GridLayout {
            Layout.fillWidth: true
            columns: pg.cols
            columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: StyleLibrary.cursors
                delegate: Card {
                    id: cu
                    required property var modelData
                    chosen: modelData.installed && modelData.themes.indexOf(Settings.cursorTheme) >= 0
                    implicitHeight: 64
                    RowLayout {
                        anchors { fill: parent; margins: 10 }
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
                        UiBtn {
                            visible: cu.modelData.installed && cu.modelData.themes.length > 0
                            label: cu.chosen ? "In use" : "Use"
                            selected: cu.chosen
                            onClicked: Settings.setDesktop("cursorTheme", cu.modelData.themes[0])
                        }
                        JobState { kind: "cursor"; arg: cu.modelData.id; installed: cu.modelData.installed; onInstall: StyleLibrary.installCursor(cu.modelData) }
                    }
                }
            }
        }
    }

    AddOwn { visible: pg.tab === "cursors"; what: "a cursor theme (a folder or archive with index.theme and a cursors/ folder)"; folder: StyleLibrary.dirs.icons || (Quickshell.env("HOME") + "/.local/share/icons"); folderLabel: "Open icons folder" }
}
