import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Greetd
import Quickshell.Widgets

// =============================================================================
//  Sleek Shell greeter — graphical login for greetd (runs as the "greeter" user inside a minimal
//  Hyprland, see ../hyprland.lua). Authentication is done by greetd + PAM; this file only relays
//  the prompts. The password lives in a TextInput until it is sent and is never written anywhere.
//
//  Preview: when greetd is not available (e.g. `quickshell -p <this dir>` inside a normal session)
//  it runs in PREVIEW mode: nothing is authenticated or launched. Type "preview" to simulate a
//  successful login, anything else simulates a failure. Esc quits the preview.
// =============================================================================
ShellRoot {
    id: root

    readonly property bool preview: !Greetd.available
    readonly property string base: Quickshell.shellDir + "/.."
    readonly property string cacheDir: Quickshell.env("XDG_CACHE_HOME") || "/var/cache/sleek-shell-greeter"

    // ---------------------------------------------------------------- look (copied from the user's Sleek Shell theme at install time)
    readonly property var palettes: ({
        navy: [[42, 38, 82], [124, 156, 255]], graphite: [[46, 46, 54], [150, 162, 184]], violet: [[58, 40, 96], [176, 140, 255]],
        rose: [[78, 34, 58], [255, 130, 180]], forest: [[26, 60, 48], [110, 220, 170]], ocean: [[24, 56, 82], [104, 190, 255]],
        ember: [[70, 40, 24], [255, 168, 96]], mocha: [[54, 46, 42], [214, 172, 136]], nord: [[40, 48, 60], [136, 192, 208]],
        tokyo: [[32, 34, 52], [122, 162, 247]], sakura: [[64, 40, 56], [255, 155, 200]], matcha: [[40, 56, 38], [168, 220, 130]]
    })
    property var look: ({ palette: "navy", accent: "" })
    FileView {
        path: root.base + "/appearance.json"
        blockLoading: true
        printErrors: false
        onLoaded: { try { root.look = JSON.parse(text()) } catch (e) {} }
    }
    property bool use24: false
    property string avatarUser: ""          // whose picture /etc/greetd/sleek-shell/avatar is (written by install.sh)
    FileView { path: root.base + "/avatar-user"; blockLoading: true; printErrors: false; onLoaded: root.avatarUser = text().trim() }
    FileView {
        path: root.base + "/settings.json"
        blockLoading: true
        printErrors: false
        onLoaded: { try { root.use24 = !!JSON.parse(text()).clock24h } catch (e) {} }
    }
    // Qt's "h" is 24-hour unless the format also contains AP
    function fmtTime(d) { return root.use24 ? Qt.formatDateTime(d, "HH:mm") : Qt.formatDateTime(d, "h:mm AP").replace(/\s?(AM|PM|am|pm)$/, "") }
    readonly property var pal: palettes[look.palette] || palettes.navy
    function rgb(a, al) { return Qt.rgba(a[0] / 255, a[1] / 255, a[2] / 255, al === undefined ? 1 : al) }
    readonly property color tint: rgb(pal[0])
    readonly property color accent: /^#[0-9a-fA-F]{6}$/.test(look.accent || "") ? look.accent : rgb(pal[1])
    readonly property color textCol: "#f4f1ff"
    readonly property color mutedCol: "#b4b0d4"
    readonly property color red: "#ff6b86"
    readonly property string font: Qt.fontFamilies().indexOf("Inter") >= 0 ? "Inter" : "Noto Sans"
    readonly property string iconFont: "JetBrainsMono Nerd Font"
    function glyph(c) { return String.fromCodePoint(c) }

    // ---------------------------------------------------------------- users & sessions
    property var users: []
    property int userIndex: 0
    property var sessions: []
    property int sessionIndex: 0
    readonly property var user: users.length ? users[userIndex] : null
    readonly property var session: sessions.length ? sessions[sessionIndex] : null

    // regular-user uid range of this system (UID_MIN/UID_MAX), defaults as in shadow-utils
    FileView { id: loginDefs; path: "/etc/login.defs"; blockLoading: true; printErrors: false }
    function loginDef(key, fallback) {
        var m = (loginDefs.text() || "").match(new RegExp("^\\s*" + key + "\\s+(\\d+)", "m"))
        return m ? parseInt(m[1]) : fallback
    }
    FileView {
        path: "/etc/passwd"
        blockLoading: true
        printErrors: false
        onLoaded: {
            var out = []
            var uidMin = root.loginDef("UID_MIN", 1000), uidMax = root.loginDef("UID_MAX", 60000)
            text().split("\n").forEach(function (l) {
                var f = l.split(":")
                if (f.length < 7) return
                var uid = parseInt(f[2])
                if (isNaN(uid) || uid < uidMin || uid > uidMax || /(nologin|false)$/.test(f[6])) return
                out.push({ name: f[0], uid: uid, real: (f[4] || "").split(",")[0] || f[0] })
            })
            root.users = out
            root.restoreLast()
        }
    }
    Process {
        running: true
        command: ["sh", "-c", "for f in /usr/share/wayland-sessions/*.desktop; do [ -f \"$f\" ] || continue; " +
                 "n=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); e=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2-); " +
                 "d=$(grep -m1 '^DesktopNames=' \"$f\" | cut -d= -f2-); h=$(grep -m1 '^NoDisplay=' \"$f\" | cut -d= -f2-); " +
                 "[ \"$h\" = true ] && continue; printf '%s\\t%s\\t%s\\t%s\\n' \"$(basename \"$f\" .desktop)\" \"$n\" \"$e\" \"$d\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                text.split("\n").forEach(function (l) {
                    var f = l.split("\t")
                    if (f.length < 3 || !f[2]) return
                    out.push({ id: f[0], name: f[1] || f[0], exec: f[2].replace(/\s%[a-zA-Z]/g, "").trim(), desktop: f[3] || f[1] })
                })
                // Hyprland first, then the rest alphabetically
                out.sort(function (a, b) { return (a.id === "hyprland" ? -1 : b.id === "hyprland" ? 1 : a.name.localeCompare(b.name)) })
                root.sessions = out
                root.restoreLast()
            }
        }
    }
    FileView { id: lastStore; path: root.cacheDir + "/last.json"; blockLoading: true; printErrors: false; atomicWrites: true }
    function restoreLast() {
        var o = {}
        try { o = JSON.parse(lastStore.text() || "{}") } catch (e) {}
        for (var i = 0; i < users.length; ++i) if (users[i].name === o.user) userIndex = i
        for (var j = 0; j < sessions.length; ++j) if (sessions[j].id === o.session) sessionIndex = j
    }
    function rememberLast() {
        if (preview) return
        lastStore.setText(JSON.stringify({ user: user ? user.name : "", session: session ? session.id : "" }) + "\n")
    }

    // ---------------------------------------------------------------- auth state machine
    property string phase: "idle"        // idle | auth | launching | done
    property string message: ""
    property bool messageIsError: false
    property string promptText: "Password"
    property bool echo: false
    property int fails: 0
    signal shake()
    signal clearField()
    signal focusField()

    function login(secret) {
        if (!user || !session || phase !== "idle") return
        message = ""; messageIsError = false
        pending = secret
        if (preview) { phase = "auth"; previewT.restart(); return }
        phase = "auth"
        Greetd.createSession(user.name)
    }
    property string pending: ""          // the secret, only until greetd asks for it
    function fail(msg) {
        pending = ""
        phase = "idle"
        fails += 1
        message = msg || "That password didn't work"
        messageIsError = true
        shake(); clearField(); focusField()
    }
    Connections {
        target: Greetd
        enabled: !root.preview
        function onAuthMessage(msg, error, responseRequired, echoResponse) {
            if (error) { root.message = msg; root.messageIsError = true }
            if (responseRequired) {
                if (root.pending !== "") { var s = root.pending; root.pending = ""; Greetd.respond(s) }
                else {                       // a second prompt (e.g. OTP): ask for it in the same field
                    root.promptText = msg || "Response"; root.echo = echoResponse; root.phase = "idle"
                    root.message = msg; root.messageIsError = false; root.clearField(); root.focusField()
                }
            } else if (!error && msg) { root.message = msg; root.messageIsError = false; Greetd.respond("") }
        }
        function onAuthFailure(msg) { Greetd.cancelSession(); root.fail(msg && msg !== "" ? msg : "That password didn't work") }
        function onReadyToLaunch() {
            root.phase = "launching"
            root.message = "Starting " + root.session.name + "…"; root.messageIsError = false
            root.rememberLast()
            Greetd.launch([root.session.exec.replace(/\s+%[fFuUdDnNickvm]/g, "").trim()], [
                "XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + root.session.id,
                "XDG_CURRENT_DESKTOP=" + root.session.desktop.split(";")[0]], true)
        }
        function onLaunched() { root.phase = "done" }
        function onError(err) { Greetd.cancelSession(); root.fail("Login error: " + err) }
    }
    Timer {
        id: previewT; interval: 700
        onTriggered: {
            var ok = root.pending === "preview"
            root.pending = ""
            if (ok) { root.phase = "launching"; root.message = "Preview: would start “" + root.session.name + "” (" + root.session.exec + ")"; quitT.restart() }
            else root.fail("Preview: wrong password (type “preview”)")
        }
    }
    Timer { id: quitT; interval: 2600; onTriggered: { root.phase = "idle"; root.message = "" } }

    function power(action) {
        if (preview) { message = "Preview: would " + action; messageIsError = false; return }
        Quickshell.execDetached(["systemctl", action])
    }

    // ---------------------------------------------------------------- clock
    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ---------------------------------------------------------------- one surface per monitor
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            readonly property bool primary: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : modelData === Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "#0c0b16"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sleek-shell-greeter"
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // wallpaper, blurred once (static image: no per-frame cost)
            Image {
                id: wall
                anchors.fill: parent
                source: "file://" + root.base + "/wallpaper"
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 1280
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: wall
                visible: wall.status === Image.Ready
                blurEnabled: true; blur: 0.85; blurMax: 48
                saturation: -0.15; brightness: -0.12
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 600 } }
            }
            Rectangle { anchors.fill: parent; gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.35) }
                GradientStop { position: 1; color: Qt.rgba(0.02, 0.02, 0.05, 0.7) } } }

            // secondary monitors: just the time
            Column {
                visible: !win.primary
                anchors.centerIn: parent
                spacing: 4
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.fmtTime(clock.date); color: root.textCol; font.family: root.font; font.pixelSize: 96; font.weight: Font.Bold }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clock.date, "dddd, d MMMM"); color: root.mutedCol; font.family: root.font; font.pixelSize: 20 }
            }

            // ---------------- primary: the login card
            FocusScope {
                id: scope
                visible: win.primary
                anchors.fill: parent
                focus: win.primary
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Escape) {
                        if (root.preview) Qt.quit()
                        else { pw.text = ""; root.message = "" }
                        e.accepted = true
                    } else if (e.key === Qt.Key_F2 || (e.key === Qt.Key_S && (e.modifiers & Qt.ControlModifier))) {
                        root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, root.sessions.length); e.accepted = true
                    } else if ((e.key === Qt.Key_Up || e.key === Qt.Key_Down) && root.users.length > 1 && root.phase === "idle") {
                        root.userIndex = (root.userIndex + (e.key === Qt.Key_Down ? 1 : -1) + root.users.length) % root.users.length; e.accepted = true
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -20
                    spacing: 0
                    width: Math.min(420, win.width - 48)

                    Text { Layout.alignment: Qt.AlignHCenter; text: root.fmtTime(clock.date); color: root.textCol; font.family: root.font; font.pixelSize: 88; font.weight: Font.Bold
                           font.features: { "tnum": 1 } }
                    Text { Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: 34; text: Qt.formatDateTime(clock.date, "dddd, d MMMM"); color: root.mutedCol; font.family: root.font; font.pixelSize: 18 }

                    Rectangle {
                        id: card
                        Layout.fillWidth: true
                        implicitHeight: cardCol.implicitHeight + 48
                        radius: 26
                        color: Qt.rgba(root.tint.r * 0.6, root.tint.g * 0.6, root.tint.b * 0.6, 0.55)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        property real dx: 0
                        transform: Translate { x: card.dx }
                        SequentialAnimation {
                            id: shakeAnim
                            NumberAnimation { target: card; property: "dx"; to: -14; duration: 50 }
                            NumberAnimation { target: card; property: "dx"; to: 12; duration: 70 }
                            NumberAnimation { target: card; property: "dx"; to: -8; duration: 60 }
                            NumberAnimation { target: card; property: "dx"; to: 0; duration: 80; easing.type: Easing.OutBack }
                        }
                        Connections { target: root; function onShake() { shakeAnim.restart() } }

                        ColumnLayout {
                            id: cardCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
                            spacing: 14

                            // user
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                ClippingRectangle {          // profile picture (synced from Settings › Lock screen) or initial
                                    implicitWidth: 56; implicitHeight: 56; radius: 28
                                    color: "transparent"
                                    Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#8be0ff" } GradientStop { position: 1; color: root.accent } } }
                                    Text { anchors.centerIn: parent; visible: avatarImg.status !== Image.Ready; text: root.user ? root.user.real.charAt(0).toUpperCase() : "?"; color: "#ffffff"; font.family: root.font; font.pixelSize: 24; font.weight: Font.Bold }
                                    Image {
                                        id: avatarImg
                                        anchors.fill: parent
                                        // only the installing user's picture is copied; other users keep their initial
                                        source: root.user && root.user.name === root.avatarUser ? "file://" + root.base + "/avatar" : ""
                                        sourceSize: Qt.size(112, 112); fillMode: Image.PreserveAspectCrop; asynchronous: true
                                        visible: status === Image.Ready
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text { text: root.user ? root.user.real : "No users found"; color: root.textCol; font.family: root.font; font.pixelSize: 19; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: root.user ? root.user.name + (root.users.length > 1 ? "  ·  ↑↓ to switch user" : "") : ""; color: root.mutedCol; font.family: root.font; font.pixelSize: 13 }
                                }
                                Row {
                                    visible: root.users.length > 1
                                    spacing: 2
                                    Repeater {
                                        model: [{ c: 0xF0141, d: -1 }, { c: 0xF0142, d: 1 }]
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: 30; height: 30; radius: 15
                                            color: uma.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                            Text { anchors.centerIn: parent; text: root.glyph(parent.modelData.c); color: root.mutedCol; font.family: root.iconFont; font.pixelSize: 16 }
                                            MouseArea { id: uma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { root.userIndex = (root.userIndex + parent.modelData.d + root.users.length) % root.users.length; pw.forceActiveFocus() } }
                                        }
                                    }
                                }
                            }

                            // password
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 50
                                radius: 25
                                color: Qt.rgba(1, 1, 1, pw.activeFocus ? 0.12 : 0.08)
                                border.width: pw.activeFocus ? 2 : 1
                                border.color: root.messageIsError ? root.red : (pw.activeFocus ? root.accent : Qt.rgba(1, 1, 1, 0.10))
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Text { text: root.glyph(0xF033E); color: root.mutedCol; font.family: root.iconFont; font.pixelSize: 18
                                       anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter } }
                                TextInput {
                                    id: pw
                                    anchors { left: parent.left; right: go.left; leftMargin: 46; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    focus: win.primary
                                    enabled: root.phase === "idle" && !!root.user
                                    echoMode: root.echo ? TextInput.Normal : TextInput.Password
                                    passwordCharacter: "●"
                                    color: root.textCol
                                    selectionColor: root.accent
                                    font.family: root.font; font.pixelSize: 16; font.letterSpacing: root.echo ? 0 : 2
                                    clip: true
                                    Accessible.role: Accessible.EditableText
                                    Accessible.name: root.promptText
                                    Accessible.passwordEdit: !root.echo
                                    onAccepted: { var s = text; text = ""; root.login(s) }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: pw.text === ""
                                        text: root.phase === "auth" ? "Checking…" : (root.phase === "launching" ? "Welcome" : root.promptText)
                                        color: root.mutedCol; font.family: root.font; font.pixelSize: 15; font.letterSpacing: 0
                                    }
                                    Connections { target: root; function onClearField() { pw.text = "" } function onFocusField() { pw.forceActiveFocus() } }
                                }
                                Rectangle {
                                    id: go
                                    width: 38; height: 38; radius: 19
                                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                                    color: gma.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent
                                    opacity: pw.text !== "" || root.phase !== "idle" ? 1 : 0.5
                                    Text { id: goIcon; anchors.centerIn: parent; text: root.glyph(root.phase === "idle" ? 0xF0142 : 0xF0450); color: "#14122a"; font.family: root.iconFont; font.pixelSize: 18 }
                                    RotationAnimator { target: goIcon; from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.phase === "auth" }
                                    MouseArea { id: gma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pw.accepted() }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.preferredHeight: implicitHeight
                                visible: root.message !== ""
                                text: root.message
                                color: root.messageIsError ? root.red : root.mutedCol
                                font.family: root.font; font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                            }

                            // session chip
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: srow.implicitWidth + 28
                                implicitHeight: 32
                                radius: 16
                                color: sma.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                                Row {
                                    id: srow
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: root.glyph(0xF0379); color: root.accent; font.family: root.iconFont; font.pixelSize: 15 }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: root.session ? root.session.name : "No sessions found"; color: root.textCol; font.family: root.font; font.pixelSize: 13 }
                                    Text { anchors.verticalCenter: parent.verticalCenter; visible: root.sessions.length > 1; text: "F2"; color: root.mutedCol; font.family: root.font; font.pixelSize: 11 }
                                }
                                MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, root.sessions.length); pw.forceActiveFocus() } }
                                Accessible.role: Accessible.Button
                                Accessible.name: "Session: " + (root.session ? root.session.name : "")
                            }
                        }
                    }
                }

                // power actions
                Row {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 28 }
                    spacing: 10
                    Repeater {
                        model: [{ c: 0xF04B2, a: "suspend", t: "Suspend" }, { c: 0xF0709, a: "reboot", t: "Restart" }, { c: 0xF0425, a: "poweroff", t: "Shut down" }]
                        delegate: Rectangle {
                            required property var modelData
                            width: 44; height: 44; radius: 22
                            color: pma.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text { anchors.centerIn: parent; text: root.glyph(parent.modelData.c); color: root.textCol; font.family: root.iconFont; font.pixelSize: 19 }
                            MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.power(parent.modelData.a) }
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.t
                        }
                    }
                }
                // brand + preview banner
                Row {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 28 }
                    spacing: 10
                    Rectangle {
                        width: 30; height: 30; radius: 15
                        gradient: Gradient { GradientStop { position: 0; color: "#8be0ff" } GradientStop { position: 1; color: root.accent } }
                        Text { anchors.centerIn: parent; text: root.glyph(0xF058C); color: "#ffffff"; font.family: root.iconFont; font.pixelSize: 16 }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Sleek Shell"; color: root.textCol; font.family: root.font; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: root.preview; text: "PREVIEW · nothing is authenticated · type “preview” · Esc exits"; color: "#ffe45e"; font.family: root.font; font.pixelSize: 12 }
                }
            }
        }
    }
}
