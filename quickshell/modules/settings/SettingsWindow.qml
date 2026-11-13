import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components
import "pages"

// Sleek Shell Settings (SUPER + I). One window, a sidebar of pages; every page edits the same
// stores the quick panels use (Theme / Settings / keybinds model), so nothing can disagree.
Scope {
    id: sw
    readonly property var pages: [
        { id: "appearance", label: "Appearance", code: Theme.ic.palette, col: Theme.blue },
        { id: "styles", label: "Fonts, icons & cursors", code: Theme.ic.font, col: Theme.purple },
        { id: "motion", label: "Motion", code: Theme.ic.speed, col: Theme.green },
        { id: "bar", label: "Bar & widgets", code: Theme.ic.dashboard, col: Theme.cyan },
        { id: "windows", label: "Windows", code: Theme.ic.window, col: Theme.purple },
        { id: "wallpaper", label: "Wallpaper", code: Theme.ic.wallpaper, col: Theme.pink },
        { id: "notifications", label: "Notifications", code: Theme.ic.bell, col: Theme.yellow },
        { id: "lock", label: "Lock screen", code: Theme.ic.lock, col: Theme.cyan },
        { id: "launcher", label: "Launcher & calculator", code: Theme.ic.apps, col: Theme.green },
        { id: "keyboard", label: "Keyboard", code: Theme.ic.keyboard, col: Theme.accent },
        { id: "displays", label: "Displays", code: Theme.ic.monitor, col: Theme.cyan },
        { id: "about", label: "About Sleek Shell", code: Theme.ic.info, col: Theme.muted }
    ]
    property bool shown: false
    Connections {
        target: Ui
        function onSettingsOpenChanged() {
            if (Ui.settingsOpen) { sw.shown = true; openAnim.restart(); focusT.restart() }
            else closeAnim.restart()
        }
    }
    Timer { id: focusT; interval: 50; onTriggered: keys.forceActiveFocus() }
    property real t: 0
    NumberAnimation { id: openAnim; target: sw; property: "t"; to: 1; duration: Theme.dur(260); easing.type: Easing.OutCubic }
    NumberAnimation { id: closeAnim; target: sw; property: "t"; to: 0; duration: Theme.dur(160); easing.type: Easing.InCubic; onFinished: sw.shown = false }

    PanelWindow {
        visible: sw.shown
        screen: Ui.settingsScreen
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-settings-dim"
        // Keep the scrim below the interactive Settings surface, which is on Overlay.
        WlrLayershell.layer: WlrLayer.Top

        Rectangle { anchors.fill: parent; color: Theme.scrim; opacity: sw.t }
    }

    PanelWindow {
        visible: sw.shown
        screen: Ui.settingsScreen
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-settings"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Ui.settingsOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) { Ui.closeSettings(); e.accepted = true }
                else if ((e.modifiers & Qt.ControlModifier) && (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab)) {
                    var i = 0
                    for (var k = 0; k < sw.pages.length; ++k) if (sw.pages[k].id === Ui.settingsPage) i = k
                    i = (i + (e.key === Qt.Key_Backtab || (e.modifiers & Qt.ShiftModifier) ? -1 : 1) + sw.pages.length) % sw.pages.length
                    Ui.settingsPage = sw.pages[i].id
                    e.accepted = true
                }
            }

            MouseArea { anchors.fill: parent; onClicked: Ui.closeSettings() }

            Item {
                id: frame
                anchors.centerIn: parent
                width: Math.min(parent.width - 40, 1180)
                height: Math.min(parent.height - 40, 780)
                opacity: sw.t
                scale: 0.96 + 0.04 * sw.t

                Rectangle {
                    visible: Theme.shadows
                    anchors { fill: parent; topMargin: 8; leftMargin: 2; rightMargin: -2; bottomMargin: -8 }
                    radius: Theme.windowRounding
                    color: Theme.shadowColor
                }
                // Window border: follows Settings > Appearance > Window and app borders
                // (thickness, common colour, the accent-to-palette gradient and the off state).
                // Drawn as a ring, not a filled rectangle, so the glass surface never picks
                // up the border tint.
                Shape {
                    id: windowBorder
                    anchors.fill: parent
                    visible: Theme.borderWidth > 0
                    preferredRendererType: Shape.CurveRenderer
                    readonly property real bw: Math.min(Theme.borderWidth, Math.min(width, height) / 2)
                    readonly property real outerRadius: Math.min(Theme.windowRounding, Math.min(width, height) / 2)
                    readonly property real innerRadius: Math.max(0, outerRadius - bw)
                    readonly property bool useGradient: Theme.colorfulBorders && Theme.windowBorderColor === ""
                    readonly property color solidColor: Theme.windowBorderColor !== ""
                        ? Theme.windowBorderColor
                        : Qt.alpha(Theme.commonBorderHex, 0.80)
                    ShapePath {
                        fillRule: ShapePath.OddEvenFill
                        strokeWidth: 0
                        fillGradient: LinearGradient {
                            id: borderGradient
                            x1: 0; y1: windowBorder.height
                            x2: windowBorder.width; y2: 0
                            GradientStop { position: 0; color: windowBorder.useGradient ? Qt.alpha(Theme.commonBorderHex, 0.93) : windowBorder.solidColor }
                            GradientStop { position: 1; color: windowBorder.useGradient ? Qt.alpha(Theme.rgb(Theme.palette.accent), 0.67) : windowBorder.solidColor }
                        }
                        // outer edge
                        startX: windowBorder.outerRadius; startY: 0
                        PathLine { x: windowBorder.width - windowBorder.outerRadius; y: 0 }
                        PathArc { x: windowBorder.width; y: windowBorder.outerRadius; radiusX: windowBorder.outerRadius; radiusY: windowBorder.outerRadius }
                        PathLine { x: windowBorder.width; y: windowBorder.height - windowBorder.outerRadius }
                        PathArc { x: windowBorder.width - windowBorder.outerRadius; y: windowBorder.height; radiusX: windowBorder.outerRadius; radiusY: windowBorder.outerRadius }
                        PathLine { x: windowBorder.outerRadius; y: windowBorder.height }
                        PathArc { x: 0; y: windowBorder.height - windowBorder.outerRadius; radiusX: windowBorder.outerRadius; radiusY: windowBorder.outerRadius }
                        PathLine { x: 0; y: windowBorder.outerRadius }
                        PathArc { x: windowBorder.outerRadius; y: 0; radiusX: windowBorder.outerRadius; radiusY: windowBorder.outerRadius }
                        // inner edge (hole)
                        PathMove { x: windowBorder.bw + windowBorder.innerRadius; y: windowBorder.bw }
                        PathLine { x: windowBorder.width - windowBorder.bw - windowBorder.innerRadius; y: windowBorder.bw }
                        PathArc { x: windowBorder.width - windowBorder.bw; y: windowBorder.bw + windowBorder.innerRadius; radiusX: windowBorder.innerRadius; radiusY: windowBorder.innerRadius }
                        PathLine { x: windowBorder.width - windowBorder.bw; y: windowBorder.height - windowBorder.bw - windowBorder.innerRadius }
                        PathArc { x: windowBorder.width - windowBorder.bw - windowBorder.innerRadius; y: windowBorder.height - windowBorder.bw; radiusX: windowBorder.innerRadius; radiusY: windowBorder.innerRadius }
                        PathLine { x: windowBorder.bw + windowBorder.innerRadius; y: windowBorder.height - windowBorder.bw }
                        PathArc { x: windowBorder.bw; y: windowBorder.height - windowBorder.bw - windowBorder.innerRadius; radiusX: windowBorder.innerRadius; radiusY: windowBorder.innerRadius }
                        PathLine { x: windowBorder.bw; y: windowBorder.bw + windowBorder.innerRadius }
                        PathArc { x: windowBorder.bw + windowBorder.innerRadius; y: windowBorder.bw; radiusX: windowBorder.innerRadius; radiusY: windowBorder.innerRadius }
                    }
                    MouseArea { anchors.fill: parent }
                }
                Rectangle {
                    id: card
                    anchors.fill: parent
                    anchors.margins: Theme.borderWidth
                    radius: Math.max(0, Theme.windowRounding - Theme.borderWidth)
                    antialiasing: true
                    clip: true
                    color: Theme.glassPopTop
                    MouseArea { anchors.fill: parent }

                    // ---------------- sidebar
                    Rectangle {
                        id: side
                        width: 252
                        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                        radius: 0
                        topLeftRadius: card.radius
                        bottomLeftRadius: card.radius
                        color: Theme.surfaceHi
                        ColumnLayout {
                            anchors { fill: parent; margins: 14 }
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                            Layout.bottomMargin: 18
                                Layout.leftMargin: 6
                                spacing: 10
                                Rectangle {
                                    implicitWidth: 40; implicitHeight: 40; radius: 14
                                    color: Theme.accent
                                    Glyph { anchors.centerIn: parent; code: Theme.ic.drop; color: Theme.onAccent; size: 20 }
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Text { text: "Desktop settings"; color: Theme.text; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Bold }
                                    Text { text: "Sleek Shell"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm }
                                }
                            }
                            Repeater {
                                model: sw.pages
                                delegate: Rectangle {
                                    id: nav
                                    required property var modelData
                                    readonly property bool current: Ui.settingsPage === modelData.id
                                    Layout.fillWidth: true
                                    implicitHeight: 46
                                    radius: 16
                                    color: current ? Theme.accent : (nma.containsMouse || activeFocus ? Theme.surface : "transparent")
                                    Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
                                    activeFocusOnTab: true
                                    Accessible.role: Accessible.PageTab
                                    Accessible.name: modelData.label
                                    Keys.onPressed: e => { if (e.key === Qt.Key_Return || e.key === Qt.Key_Space) { Ui.settingsPage = modelData.id; e.accepted = true } }
                                    Rectangle {
                                        width: 3; height: nav.current ? 18 : 0; radius: 2
                                        anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                                        visible: false
                                        color: Theme.accent
                                        Behavior on height { enabled: Theme.animations; NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutBack } }
                                    }
                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                                        spacing: 10
                                        Glyph { code: nav.modelData.code; color: nav.current ? Theme.onAccent : Theme.muted; size: 19 }
                                        Text { text: nav.modelData.label; color: nav.current ? Theme.onAccent : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontLg
                                               font.weight: nav.current ? Font.DemiBold : Font.Normal; Layout.fillWidth: true; elide: Text.ElideRight }
                                    }
                                    MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.settingsPage = nav.modelData.id }
                                }
                            }
                            Item { Layout.fillHeight: true }
                            Text {
                                Layout.fillWidth: true
                                Layout.leftMargin: 6
                                text: "Esc closes · Ctrl+Tab switches pages"
                                color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontXs
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    Rectangle { anchors { top: parent.top; bottom: parent.bottom; left: side.right } width: 1; color: Theme.separator }

                    // ---------------- page
                    Loader {
                        id: pageLoader
                        anchors { top: parent.top; bottom: parent.bottom; left: side.right; right: parent.right; leftMargin: 1 }
                        active: sw.shown
                        sourceComponent: ({ appearance: pAppearance, styles: pStyles, motion: pMotion, bar: pBar, windows: pWindows, wallpaper: pWallpaper,
                                            notifications: pNotifications, lock: pLock, launcher: pLauncher, keyboard: pKeyboard, displays: pDisplays, about: pAbout })[Ui.settingsPage]
                        opacity: status === Loader.Ready ? 1 : 0
                        onSourceComponentChanged: if (Theme.animations) fadeIn.restart()
                        NumberAnimation { id: fadeIn; target: pageLoader; property: "y"; from: 8; to: 0; duration: Theme.dur(220); easing.type: Easing.OutCubic }
                    }
                    IconButton {
                        anchors { top: parent.top; right: parent.right; margins: 12 }
                        code: Theme.ic.close; tooltip: "Close settings"
                        onClicked: Ui.closeSettings()
                    }
                }
            }
        }
    }

    Component { id: pAppearance; AppearancePage {} }
    Component { id: pStyles; StylesPage {} }
    Component { id: pMotion; MotionPage {} }
    Component { id: pBar; BarPage {} }
    Component { id: pWindows; WindowsPage {} }
    Component { id: pWallpaper; WallpaperPage {} }
    Component { id: pNotifications; NotificationsPage {} }
    Component { id: pLock; LockPage {} }
    Component { id: pLauncher; LauncherPage {} }
    Component { id: pKeyboard; KeyboardPage {} }
    Component { id: pDisplays; DisplaysPage {} }
    Component { id: pAbout; AboutPage {} }
}
