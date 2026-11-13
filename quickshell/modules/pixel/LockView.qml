import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.services

// The whole lock screen visual: wallpaper, shade, big clock, date and password
// field.  It is deliberately still apart from a short fade-in when the session
// locks.  A WlSessionLockSurface can render it, and the Settings preview can
// reuse it with injected values.
Item {
    id: view
    property var ctl: null
    property bool primary: true
    // Screen name of the surface this view is rendered on (empty in previews).
    // Used to move the single password field to whichever screen is typed on.
    property string surfaceScreen: ""
    property date now: new Date()

    // Injected in previews; the real lock surface takes them from Settings/Theme.
    property string clockStyle: Settings.lockClockStyle
    property string wallpaperPath: Settings.lockWallpaper
    property string surfaceStyle: Settings.lockStyleMode === "inherit" ? Theme.styleMode : Settings.lockStyleMode
    property int wallpaperBlur: Settings.lockBlur
    property int wallpaperShade: Settings.lockShade
    property string fontFamily: Theme.font
    property bool is24h: ctl && ctl.clock24h !== undefined ? ctl.clock24h : Settings.clock24h

    readonly property string resolvedWallpaper: wallpaperPath.trim().replace(/^~(?=\/|$)/, Quickshell.env("HOME"))
    readonly property string password: ctl ? ctl.password : ""
    readonly property string message: ctl ? ctl.message : ""
    readonly property bool authenticating: ctl ? ctl.authenticating : false

    // Simple entry: the lock surface starts transparent and fades in over the
    // surface colour, so locking does not flash the whole desktop at once.
    property real reveal: 0
    opacity: (primary ? 1 : 0.76) * reveal
    NumberAnimation {
        id: entry
        target: view
        property: "reveal"
        from: 0; to: 1
        duration: Theme.animations ? 220 : 0
        easing.type: Easing.OutCubic
    }
    function playEntry() { if (!view.ctl || view.ctl.locked) entry.restart() }
    Component.onCompleted: playEntry()
    Connections {
        target: view.ctl
        ignoreUnknownSignals: true
        function onLockedChanged() {
            if (view.ctl.locked) { view.now = new Date(); entry.restart() }
            else view.reveal = 0
        }
    }

    Timer {
        interval: 1000
        repeat: true
        // Only tick while the lock is actually up; unlocked surfaces stay still.
        running: !view.ctl || view.ctl.locked
        onTriggered: view.now = new Date()
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: view.resolvedWallpaper !== "" ? "file://" + view.resolvedWallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: status === Image.Ready
    }
    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        visible: blurEnabled
        blurEnabled: view.surfaceStyle === "glass" && view.wallpaperBlur > 0
        blur: blurEnabled ? 1.0 : 0
        blurMax: blurEnabled ? view.wallpaperBlur : 0
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha("#080a10", 0.16 + view.wallpaperShade / 200) }
            GradientStop { position: 0.56; color: Qt.alpha("#0b0d14", 0.28 + view.wallpaperShade / 160) }
            GradientStop { position: 1; color: Qt.alpha("#080a10", 0.42 + view.wallpaperShade / 160) }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(view.width * 0.9, 1050)
        spacing: Math.max(8, view.height * 0.012)

        LockClock {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(view.height * 0.34, 310)
            now: view.now
            is24h: view.is24h
            style: view.clockStyle
            fontFamily: view.fontFamily
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(view.now, "dddd, MMMM d") + (view.is24h ? "" : "  ·  " + (view.now.getHours() < 12 ? "AM" : "PM"))
            color: Qt.alpha("#f0f2f5", 0.78)
            font.family: view.fontFamily
            font.pixelSize: Math.max(14, Math.min(18, view.height * 0.021))
        }

        Item { Layout.preferredHeight: Math.max(18, view.height * 0.04) }

        Rectangle {
            id: passCapsule
            visible: view.ctl !== null
            // Only the focused monitor shows the password entry. The hidden
            // copies stay alive so typing works from any screen, but the dots
            // and the prompt appear on one display only.
            opacity: view.primary ? 1 : 0
            Behavior on opacity { enabled: Theme.animations; NumberAnimation { duration: 120 } }
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.maximumWidth: 340
            Layout.preferredHeight: 54
            radius: height / 2
            color: view.surfaceStyle === "solid" ? "#171a21" : Qt.alpha("#171a21", 0.82)
            border.width: pw.activeFocus ? 1 : 0
            border.color: Qt.alpha("#c8d1dc", 0.72)
            clip: true

            TextInput {
                id: pw
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                cursorVisible: false
                cursorDelegate: Item { visible: false; width: 0; height: 0 }
                color: "transparent"
                opacity: 0
                selectedTextColor: "transparent"
                selectionColor: "transparent"
                font.family: view.fontFamily
                font.pixelSize: 14
                enabled: view.ctl !== null && !view.ctl.authenticating && !view.ctl.unlocking
                text: view.password
                onTextEdited: if (view.ctl) view.ctl.password = text
                onAccepted: if (view.ctl) view.ctl.submit()
                // If the user starts typing on another display, move the single
                // password field there so the dots are never invisible.
                Keys.onPressed: if (view.ctl && !view.primary && view.surfaceScreen !== "")
                    view.ctl.primaryScreen = view.surfaceScreen
                Keys.onEscapePressed: { if (view.ctl) view.ctl.password = ""; event.accepted = true }
                onActiveFocusChanged: if (activeFocus) cursorVisible = false
                Component.onCompleted: { forceActiveFocus(); cursorVisible = false }
                Connections {
                    target: view.ctl
                    ignoreUnknownSignals: true
                    function onPasswordChanged() { if (view.ctl && pw.text !== view.ctl.password) pw.text = view.ctl.password }
                    function onLockedChanged() { if (view.ctl && view.ctl.locked && view.primary) pw.forceActiveFocus() }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: view.password.length === 0
                text: view.authenticating ? "Checking…" : "Enter password"
                color: Qt.alpha("#e7eaf0", 0.62)
                font.family: view.fontFamily
                font.pixelSize: 14
            }
            Row {
                anchors.centerIn: parent
                spacing: 9
                Repeater {
                    model: view.password.length
                    delegate: Rectangle {
                        width: 9; height: 9; radius: 4.5
                        color: "#f0f3f7"
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: view.ctl !== null && view.message !== "" && view.primary
            text: view.message
            color: "#ffc3bd"
            font.family: view.fontFamily
            font.pixelSize: 13
        }
    }
}
