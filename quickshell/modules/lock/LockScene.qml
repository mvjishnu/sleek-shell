import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components
import qs.modules.lock

// =============================================================================
//  LockScene — everything drawn while the session is locked (one per monitor).
//
//  Look: the Sleek Shell greeter's language, so locking and logging in feel like the same OS —
//  your wallpaper blurred under a palette-tinted scrim, a large clock in the UI font, one glass
//  card (padlock badge, your name, capsule password field) and status / media / power at the edges.
//
//  Motion (unchanged idea): the bar's clock pill lets go, turns into a round badge, the padlock drops
//  out of it spinning and clicks shut, then the glass grows out of the badge and dissolves into the
//  lock scene. Unlocking plays it backwards. Reduced motion (Settings › Motion) skips straight to it.
//
//  Privacy: the desktop is only ever shown as a heavy blur during the first few frames; the lock scene
//  itself is the (opaque) wallpaper, so nothing of your windows can be read through it.
//  Colours are copied from Theme once per lock, so theme edits while locked change nothing.
//
//  `primary` monitors get the card; the others get the clock only (input still works everywhere).
// =============================================================================
Item {
    id: scene

    required property var ctl
    property string shotPath: ""
    property bool primary: true

    // ---- animation state ---------------------------------------------------
    property real drop: 0      // 0 = at the bar, 1 = resting in the card's badge
    property real morph: 0     // 0 = bar clock pill, 1 = round badge
    property real spin: 0      // padlock rotation progress
    property real latch: 0     // 0 = shackle open, 1 = shut
    property real grow: 0      // 0 = badge, 1 = full-screen glass (dissolved into the scene)
    property real content: 0   // lock UI fade-in
    property real frostIn: 0   // the blurred desktop snapshot is ready
    readonly property real badge: 64
    property bool introStarted: false
    property string armedPower: ""

    // ---- frozen theme (filled in once, on lock) ----------------------------
    property color fTint: "#2a2652"
    property color fAccent: "#7c9cff"
    property color fPillTop: "#1a2652"
    property color fPillBottom: "#1a2652"
    property color fRed: "#ff6b86"
    property color fGreen: "#a5f58b"
    property color fCyan: "#8be0ff"
    property real islandHeight: 26
    property real barMargin: 3
    property real clockW: 200
    property bool use24: false
    property string font: "Noto Sans"
    readonly property color white: "#f6f4ff"
    readonly property color soft: Qt.rgba(1, 1, 1, 0.66)
    readonly property color faint: Qt.rgba(1, 1, 1, 0.42)

    Behavior on frostIn { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    SystemClock { id: clk; precision: SystemClock.Minutes }

    function freezeTheme() {
        var t = Theme.palette.tint
        fTint = Qt.rgba(t[0] / 255, t[1] / 255, t[2] / 255, 1)
        fAccent = Theme.accentBase
        fPillTop = Theme.glassBarTop
        fPillBottom = Theme.glassBarBottom
        islandHeight = Theme.islandHeight
        barMargin = Theme.barMargin
        clockW = Sys.clockW
        use24 = Settings.clock24h
        font = Theme.font
    }

    Component.onCompleted: {
        freezeTheme()
        pwInput.forceActiveFocus()
        startIntro()
        settleWatchdog.restart()
    }

    function settle() { morph = 1; drop = 1; spin = 1; latch = 1; grow = 1; content = 1 }
    function startIntro() {
        if (introStarted || scene.ctl.unlocking) return
        introStarted = true
        if (!Theme.animations) settle(); else intro.start()
    }

    // ---- identity / wallpaper ---------------------------------------------------------
    readonly property string userName: Quickshell.env("USER") || ""
    property string realName: userName
    FileView {
        path: "/etc/passwd"; blockLoading: true; printErrors: false
        onLoaded: {
            var l = text().split("\n")
            for (var i = 0; i < l.length; ++i) {
                var f = l[i].split(":")
                if (f[0] === scene.userName && f.length > 4) { var n = (f[4] || "").split(",")[0]; if (n) scene.realName = n; break }
            }
        }
    }
    property string wallPath: ""
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/awww-rice/last-wallpaper"; blockLoading: true; printErrors: false
        onLoaded: scene.wallPath = text().trim()
    }
    // Qt's "h" is 24-hour unless the format also contains AP, so format with AP and drop the suffix
    function fmtTime(d) { return use24 ? Qt.formatDateTime(d, "HH:mm") : Qt.formatDateTime(d, "h:mm AP").replace(/\s?(AM|PM|am|pm)$/, "") }

    // ============================================================== background
    // 1. opaque base: the desktop can never show through
    Rectangle { anchors.fill: parent; color: Qt.darker(scene.fTint, 2.6) }

    // 2. the desktop snapshot, heavily blurred, only for the first frames of the animation
    Item {
        id: frostBox
        width: Math.max(64, scene.width / LockStyle.frostScale)
        height: Math.max(64, scene.height / LockStyle.frostScale)
        x: (scene.width - width) / 2; y: (scene.height - height) / 2
        scale: LockStyle.frostScale
        opacity: scene.frostIn * (1 - scene.grow)
        visible: opacity > 0.001
        Image {
            id: shot
            anchors.fill: parent
            source: scene.shotPath
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
            onStatusChanged: scene.frostIn = (status === Image.Ready) ? 1 : 0
        }
        MultiEffect {
            anchors.fill: parent; source: shot; visible: shot.status === Image.Ready
            blurEnabled: true; blur: 1; blurMax: LockStyle.blurRadius
            saturation: LockStyle.saturation; brightness: LockStyle.brightness
        }
    }

    // 3. the lock scene backdrop: wallpaper, blurred once on a small copy, plus the greeter's scrim
    Item {
        id: backdrop
        anchors.fill: parent
        opacity: scene.grow
        visible: opacity > 0.001
        Item {
            width: Math.max(64, scene.width / 4); height: Math.max(64, scene.height / 4)
            x: (scene.width - width) / 2; y: (scene.height - height) / 2
            scale: 4
            Image {
                id: wall
                anchors.fill: parent
                source: scene.wallPath !== "" ? "file://" + scene.wallPath : ""
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: parent; source: wall; visible: wall.status === Image.Ready
                blurEnabled: true; blur: 0.9; blurMax: 24
                saturation: -0.1; brightness: -0.06
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(scene.fTint.r, scene.fTint.g, scene.fTint.b, 0.38) }
                GradientStop { position: 1; color: Qt.rgba(0.02, 0.02, 0.05, 0.72) }
            }
        }
    }

    // 4. the glass: starts exactly on the bar's clock pill, becomes the badge, grows to the screen
    //    and dissolves into the backdrop (alpha falls as it grows)
    Rectangle {
        id: glass
        readonly property real startCY: scene.barMargin + scene.islandHeight / 2
        // the padlock comes to rest just above the clock (on every monitor), never on the profile picture
        readonly property real restCY: clockCol.y - 30
        readonly property real w1: scene.clockW + (scene.badge - scene.clockW) * scene.morph
        readonly property real h1: scene.islandHeight + (scene.badge - scene.islandHeight) * scene.morph
        readonly property real cy1: startCY + (restCY - startCY) * scene.drop
        x: ((scene.width - w1) / 2) * (1 - scene.grow)
        y: (cy1 - h1 / 2) * (1 - scene.grow)
        width: w1 + (scene.width - w1) * scene.grow
        height: h1 + (scene.height - h1) * scene.grow
        radius: Math.min(height / 2, (h1 / 2) * (1 - scene.grow))
        antialiasing: true
        opacity: 1 - Math.max(0, (scene.grow - 0.35) / 0.65)
        visible: opacity > 0.001
        gradient: Gradient {
            GradientStop { position: 0; color: LockStyle.lerp(scene.fPillTop, Qt.rgba(scene.fTint.r, scene.fTint.g, scene.fTint.b, 0.9), scene.morph) }
            GradientStop { position: 1; color: LockStyle.lerp(scene.fPillBottom, Qt.darker(scene.fTint, 1.4), scene.morph) }
        }
        // the bar's clock text, while this is still the bar's pill
        Row {
            anchors.centerIn: parent
            spacing: 7
            opacity: Math.max(0, 1 - scene.morph * 3)
            visible: opacity > 0
            Text { text: Time.fmtTime(clk.date); color: scene.white; font.family: scene.font; font.pixelSize: Theme.barLabelSize; font.weight: Font.DemiBold }
            Text { text: Time.fmtDate(clk.date); color: scene.soft; font.family: scene.font; font.pixelSize: Theme.barLabelSize - 1 }
        }
    }

    // ============================================================== padlock
    // Drawn from shapes so it can morph (shackle opens / closes). Rests in the card's badge.
    Item {
        id: padlock
        z: 2                      // above the card, so it sits ON the badge
        property real wobble: 0
        readonly property real k: 0.78
        width: 34 * k; height: 46 * k
        x: (scene.width - width) / 2
        y: glass.cy1 - height / 2
        opacity: Math.max(0, Math.min(1, (scene.morph - 0.25) * 2.5))
        rotation: 360 * (1 - scene.spin) + wobble
        Rectangle {
            width: 20 * padlock.k; height: 34 * padlock.k; radius: width / 2
            x: (parent.width - width) / 2
            y: 4 * padlock.k - 8 * padlock.k * (1 - scene.latch)
            color: "transparent"
            border.width: 3
            border.color: scene.white
        }
        Rectangle {
            width: 32 * padlock.k; height: 24 * padlock.k; radius: 6
            x: (parent.width - width) / 2
            y: parent.height - height
            color: scene.white
            Rectangle { width: 5; height: 5; radius: 2.5; color: scene.fAccent; anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.3 }
            Rectangle { width: 2.5; height: 6; radius: 1.25; color: scene.fAccent; anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.3 + 3 }
        }
    }

    // ============================================================== lock UI
    Item {
        id: ui
        anchors.fill: parent
        opacity: scene.content
        transform: Translate { y: 14 * (1 - scene.content) }

        // clock (every monitor)
        Column {
            id: clockCol
            anchors.horizontalCenter: parent.horizontalCenter
            y: scene.primary ? Math.max(48, card.y - height - 36) : (parent.height - height) / 2
            spacing: 2
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: scene.fmtTime(clk.date); color: scene.white; font.family: scene.font
                   font.pixelSize: scene.primary ? 92 : 104; font.weight: Font.Bold; font.features: { "tnum": 1 } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clk.date, "dddd, d MMMM"); color: scene.soft
                   font.family: scene.font; font.pixelSize: 19 }
        }

        // the card
        Rectangle {
            id: card
            visible: scene.primary
            width: Math.min(400, scene.width - 48)
            height: cardCol.implicitHeight + 44
            x: (scene.width - width) / 2
            y: (scene.height - height) / 2 + 40
            radius: 28
            color: Qt.rgba(scene.fTint.r * 0.55, scene.fTint.g * 0.55, scene.fTint.b * 0.55, 0.5)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)
            Rectangle {   // liquid-glass sheen
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
                height: parent.height * 0.4; radius: parent.radius - 1
                gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.06) } GradientStop { position: 1; color: "transparent" } }
            }
            property real shakeX: 0
            transform: Translate { x: card.shakeX }

            ColumnLayout {
                id: cardCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22 }
                spacing: 12

                // profile picture (Settings › Lock screen), or the initial
                Avatar {
                    Layout.alignment: Qt.AlignHCenter
                    size: 76
                    name: scene.realName
                    tone: scene.fAccent
                    showPicture: Settings.lockAvatar
                    border.width: 2
                    border.color: Qt.rgba(1, 1, 1, 0.18)
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 1
                    Text { Layout.alignment: Qt.AlignHCenter; text: scene.realName; color: scene.white; font.family: scene.font; font.pixelSize: 20; font.weight: Font.DemiBold }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Locked" + (Settings.lockShowNotifications && Notifs.history.length ? " · " + Notifs.history.length + (Notifs.history.length === 1 ? " notification" : " notifications") : "")
                           color: scene.faint; font.family: scene.font; font.pixelSize: 13 }
                }

                // password capsule: one PlayStation symbol per typed character
                Rectangle {
                    id: field
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 52
                    radius: 26
                    color: scene.ctl.failFlash ? Qt.rgba(1, 0.42, 0.53, 0.22) : Qt.rgba(1, 1, 1, pwInput.activeFocus ? 0.11 : 0.07)
                    border.width: 2
                    border.color: scene.ctl.failFlash || scene.ctl.message !== "" ? scene.fRed : (scene.ctl.password.length > 0 ? scene.fAccent : Qt.rgba(1, 1, 1, 0.12))
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    Glyph { x: 10; width: 30; height: parent.height; name: "lock"; color: scene.faint; size: 18 }
                    Text {
                        anchors { left: parent.left; leftMargin: 44; verticalCenter: parent.verticalCenter }
                        visible: scene.ctl.password.length === 0
                        text: scene.ctl.busy ? "Checking…" : "Password"
                        color: scene.faint
                        font.family: scene.font; font.pixelSize: 15
                    }
                    Row {
                        // full field height, so the pop-in overshoot is not clipped; clip only trims overflow on the right
                        anchors { left: parent.left; leftMargin: 44; right: go.left; rightMargin: 8; top: parent.top; bottom: parent.bottom }
                        spacing: 6
                        clip: true
                        Repeater {
                            model: Math.min(scene.ctl.password.length, 9)
                            delegate: PsSymbol {
                                required property int index
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22; height: 22
                                kind: (Math.max(0, scene.ctl.password.length - 9) + index) % 4
                                fail: scene.ctl.failFlash
                            }
                        }
                    }
                    Rectangle {
                        id: go
                        width: 40; height: 40; radius: 20
                        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        color: gma.containsMouse ? Qt.lighter(scene.fAccent, 1.1) : scene.fAccent
                        opacity: scene.ctl.password.length > 0 || scene.ctl.busy ? 1 : 0.45
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                        Glyph {
                            id: goIcon
                            anchors.fill: parent
                            name: scene.ctl.busy || scene.ctl.unlocking ? "spinner" : "arrowForward"
                            color: Theme.luminance(scene.fAccent) > 0.55 ? "#14122a" : "#ffffff"
                            size: 20
                            RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: scene.ctl.busy }
                        }
                        MouseArea { id: gma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: scene.ctl.submit() }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: scene.ctl.message !== "" ? scene.ctl.message : (scene.ctl.password.length > 0 ? "Press Enter to unlock" : "Type your password to unlock")
                    color: scene.ctl.message !== "" ? scene.fRed : scene.faint
                    font.family: scene.font; font.pixelSize: 12
                }
            }
        }

        // now playing (only while something plays or is paused)
        Rectangle {
            id: media
            readonly property var p: Sys.player
            visible: scene.primary && !!p && Settings.lockShowMedia
            width: Math.min(400, scene.width - 48); height: 58
            x: card.x; y: card.y + card.height + 14
            radius: 20
            color: Qt.rgba(scene.fTint.r * 0.55, scene.fTint.g * 0.55, scene.fTint.b * 0.55, 0.45)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                spacing: 10
                Rectangle {
                    implicitWidth: 40; implicitHeight: 40; radius: 10; clip: true; color: Qt.rgba(1, 1, 1, 0.08)
                    Glyph { anchors.fill: parent; name: "music"; color: scene.soft; size: 18; visible: art.status !== Image.Ready }
                    Image { id: art; anchors.fill: parent; source: media.p && media.p.trackArtUrl ? media.p.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(80, 80) }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: media.p ? (media.p.trackTitle || media.p.identity || "") : ""; color: scene.white; font.family: scene.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: media.p ? (media.p.trackArtist || media.p.identity || "") : ""; color: scene.faint; font.family: scene.font; font.pixelSize: 11 }
                }
                Repeater {
                    model: [{ n: "skipPrev", f: function () { Sys.mediaPrev() } },
                            { n: Sys.mediaPlaying ? "pause" : "play", f: function () { Sys.mediaPlayPause() } },
                            { n: "skipNext", f: function () { Sys.mediaNext() } }]
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: 34; implicitHeight: 34; radius: 17
                        color: mma.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        Glyph { anchors.fill: parent; name: parent.modelData.n; color: scene.white; size: 20 }
                        MouseArea { id: mma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { parent.modelData.f(); pwInput.forceActiveFocus() } }
                    }
                }
            }
        }

        // bottom-left: brand
        Row {
            visible: scene.primary
            anchors { left: parent.left; bottom: parent.bottom; margins: 28 }
            spacing: 10
            Rectangle {
                width: 30; height: 30; radius: 15
                gradient: Gradient { GradientStop { position: 0; color: scene.fCyan } GradientStop { position: 1; color: scene.fAccent } }
                Glyph { anchors.fill: parent; code: Theme.ic.drop; color: "#ffffff"; size: 16 }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Sleek Shell"; color: scene.white; font.family: scene.font; font.pixelSize: 15; font.weight: Font.DemiBold }
        }

        // bottom-right: status + power
        Row {
            visible: scene.primary
            anchors { right: parent.right; bottom: parent.bottom; margins: 28 }
            spacing: 10
            Rectangle {   // status capsule
                height: 44; radius: 22
                width: srow.implicitWidth + 28
                color: Qt.rgba(1, 1, 1, 0.07)
                Row {
                    id: srow
                    anchors.centerIn: parent
                    spacing: 12
                    Glyph { visible: Sys.wifiOn; width: 20; height: 44; name: Theme.wifiSym(Sys.wifiOn, Sys.ssid, Sys.wifiSignal); color: scene.white; size: 18 }
                    Row {
                        visible: Sys.hasBattery
                        spacing: 4
                        Glyph { width: 16; height: 44; name: Theme.batterySym(Sys.batCap, Sys.batState); color: Sys.batCap < 20 && Sys.batState !== "Charging" ? scene.fRed : scene.white; size: 18 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: Sys.batCap + "%"; color: scene.white; font.family: scene.font; font.pixelSize: 13; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
                    }
                }
            }
            Timer { id: powerDisarm; interval: 4000; onTriggered: scene.armedPower = "" }
            Repeater {
                model: [{ n: "sleep", a: "suspend", t: "Suspend", c: false }, { n: "restart", a: "reboot", t: "Restart", c: true }, { n: "power", a: "poweroff", t: "Shut down", c: true }]
                delegate: Rectangle {
                    id: pbtn
                    required property var modelData
                    readonly property bool armed: scene.armedPower === modelData.a
                    width: 44; height: 44; radius: 22
                    color: armed ? Qt.alpha(scene.fRed, pma.containsMouse ? 0.75 : 0.55) : pma.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Glyph { anchors.fill: parent; name: pbtn.modelData.n; color: scene.white; size: 20 }
                    Rectangle {
                        visible: pbtn.armed
                        anchors { bottom: parent.top; bottomMargin: 10; right: parent.right }
                        height: 30; radius: 15
                        width: hint.implicitWidth + 24
                        color: Qt.rgba(0, 0, 0, 0.55)
                        Text { id: hint; anchors.centerIn: parent; text: "Click again to " + pbtn.modelData.t.toLowerCase(); color: scene.white; font.family: scene.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                    }
                    MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const a = pbtn.modelData.a
                            if (pbtn.modelData.c && scene.armedPower !== a) { scene.armedPower = a; powerDisarm.restart() }
                            else { scene.armedPower = ""; powerDisarm.stop(); if (!scene.ctl.testMode) Quickshell.execDetached(["systemctl", a]) }
                            pwInput.forceActiveFocus()
                        } }
                    Accessible.role: Accessible.Button
                    Accessible.name: armed ? "Confirm " + modelData.t : modelData.t
                    Accessible.description: modelData.c ? "Asks for confirmation" : ""
                }
            }
        }
    }

    // ============================================================== animations
    ParallelAnimation {
        id: intro
        NumberAnimation { target: scene; property: "morph"; to: 1; duration: LockStyle.morphDur; easing.type: Easing.OutCubic }
        NumberAnimation { target: scene; property: "drop"; to: 1; duration: LockStyle.dropDur; easing.type: Easing.OutQuint }
        NumberAnimation { target: scene; property: "spin"; to: 1; duration: LockStyle.spinDur; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: LockStyle.latchDelay }
            NumberAnimation { target: scene; property: "latch"; to: 1; duration: LockStyle.latchDur; easing.type: Easing.OutBack; easing.overshoot: 1.7 }
        }
        SequentialAnimation {
            PauseAnimation { duration: LockStyle.growDelay }
            NumberAnimation { target: scene; property: "grow"; to: 1; duration: LockStyle.growDur; easing.type: Easing.OutQuint }
        }
        SequentialAnimation {
            PauseAnimation { duration: LockStyle.contentDelay }
            NumberAnimation { target: scene; property: "content"; to: 1; duration: LockStyle.contentDur; easing.type: Easing.OutCubic }
        }
    }
    ParallelAnimation {
        id: outro
        NumberAnimation { target: scene; property: "content"; to: 0; duration: LockStyle.outContentDur; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: LockStyle.outLatchDelay }
            NumberAnimation { target: scene; property: "latch"; to: 0; duration: LockStyle.outLatchDur; easing.type: Easing.OutBack; easing.overshoot: 1.7 }
        }
        SequentialAnimation {
            PauseAnimation { duration: LockStyle.outGrowDelay }
            NumberAnimation { target: scene; property: "grow"; to: 0; duration: LockStyle.outGrowDur; easing.type: Easing.InOutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: LockStyle.outGrowDelay }
            ParallelAnimation {
                NumberAnimation { target: scene; property: "drop"; to: 0; duration: LockStyle.outDropDur; easing.type: Easing.InCubic }
                NumberAnimation { target: scene; property: "morph"; to: 0; duration: LockStyle.outMorphDur; easing.type: Easing.InOutCubic }
                NumberAnimation { target: scene; property: "spin"; to: 2; duration: LockStyle.outSpinDur; easing.type: Easing.InOutCubic }
            }
        }
    }
    // if the shell was suspended mid-animation, snap to the finished state instead of a half-drawn lock
    Timer {
        id: settleWatchdog
        interval: 1400
        onTriggered: if (!scene.ctl.unlocking && scene.grow < 1) scene.settle()
    }
    SequentialAnimation {
        id: wobbleAnim
        NumberAnimation { target: padlock; property: "wobble"; to: -14; duration: 60 }
        NumberAnimation { target: padlock; property: "wobble"; to: 11; duration: 80 }
        NumberAnimation { target: padlock; property: "wobble"; to: -7; duration: 70 }
        NumberAnimation { target: padlock; property: "wobble"; to: 0; duration: 70 }
    }
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: card; property: "shakeX"; to: -16; duration: 55 }
        NumberAnimation { target: card; property: "shakeX"; to: 13; duration: 70 }
        NumberAnimation { target: card; property: "shakeX"; to: -9; duration: 70 }
        NumberAnimation { target: card; property: "shakeX"; to: 5; duration: 60 }
        NumberAnimation { target: card; property: "shakeX"; to: 0; duration: 60 }
    }
    Connections {
        target: scene.ctl
        function onUnlockingChanged() { if (scene.ctl.unlocking) { intro.stop(); if (Theme.animations) outro.start(); else scene.content = 0 } }
        function onFailed() { shakeAnim.restart(); wobbleAnim.restart() }
        function onPasswordChanged() { if (pwInput.text !== scene.ctl.password) pwInput.text = scene.ctl.password }
    }

    // ============================================================== input
    // hidden input that receives the keyboard; the password is only held by Lock.qml until PAM asks
    TextInput {
        id: pwInput
        width: 1; height: 1
        opacity: 0
        focus: true
        echoMode: TextInput.Password
        onTextChanged: {
            if (scene.ctl.unlocking || scene.ctl.failFlash) { if (text !== scene.ctl.password) text = scene.ctl.password; return }
            if (scene.ctl.password !== text) scene.ctl.password = text
            if (text !== "") scene.ctl.message = ""
        }
        onAccepted: scene.ctl.submit()
        Keys.onEscapePressed: text = ""
        Keys.onPressed: event => {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_U) { text = ""; event.accepted = true }
        }
    }
    MouseArea { anchors.fill: parent; z: -1; onClicked: pwInput.forceActiveFocus() }
}
