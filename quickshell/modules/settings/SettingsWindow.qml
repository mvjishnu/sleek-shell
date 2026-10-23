import QtQuick
import QtQuick.Layouts
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
        WlrLayershell.namespace: "quickshell"
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

            Rectangle { anchors.fill: parent; color: Theme.scrim; opacity: sw.t }
            MouseArea { anchors.fill: parent; onClicked: Ui.closeSettings() }

            Item {
                id: frame
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 1080)
                height: Math.min(parent.height - 48, 720)
                opacity: sw.t
                scale: 0.96 + 0.04 * sw.t

                Rectangle {
                    visible: Theme.shadows
                    anchors { fill: parent; topMargin: 8; leftMargin: 2; rightMargin: -2; bottomMargin: -8 }
                    radius: Theme.radius + 4
                    color: Theme.shadowColor
                }
                Rectangle {
                    id: card
                    anchors.fill: parent
                    radius: Theme.radius + 4
                    antialiasing: true
                    clip: true
                    border.width: Theme.strokeWidth
                    border.color: Theme.stroke
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.glassPopTop }
                        GradientStop { position: 1; color: Theme.glassPopBottom }
                    }
                    MouseArea { anchors.fill: parent }

                    // ---------------- sidebar
                    Rectangle {
                        id: side
                        width: 230
                        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                        color: Qt.alpha(Theme.ink, Theme.light ? 0.03 : 0.04)
                        ColumnLayout {
                            anchors { fill: parent; margins: 14 }
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.bottomMargin: 12
                                Layout.leftMargin: 6
                                spacing: 10
                                Rectangle {
                                    implicitWidth: 34; implicitHeight: 34; radius: Theme.pill(34)
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: Theme.cyan }
                                        GradientStop { position: 1; color: Theme.accent }
                                    }
                                    Glyph { anchors.centerIn: parent; code: Theme.ic.drop; color: "#ffffff"; size: 18 }
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Text { text: "Sleek Shell"; color: Theme.text; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.Bold }
                                    Text { text: "Settings"; color: Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontSm }
                                }
                            }
                            Repeater {
                                model: sw.pages
                                delegate: Rectangle {
                                    id: nav
                                    required property var modelData
                                    readonly property bool current: Ui.settingsPage === modelData.id
                                    Layout.fillWidth: true
                                    implicitHeight: 38
                                    radius: Theme.controlRadius
                                    color: current ? Qt.alpha(Theme.accent, 0.22) : (nma.containsMouse || activeFocus ? Theme.surface : "transparent")
                                    Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
                                    activeFocusOnTab: true
                                    Accessible.role: Accessible.PageTab
                                    Accessible.name: modelData.label
                                    Keys.onPressed: e => { if (e.key === Qt.Key_Return || e.key === Qt.Key_Space) { Ui.settingsPage = modelData.id; e.accepted = true } }
                                    Rectangle {
                                        width: 3; height: nav.current ? 18 : 0; radius: 2
                                        anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                                        color: Theme.accent
                                        Behavior on height { enabled: Theme.animations; NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutBack } }
                                    }
                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                                        spacing: 10
                                        Glyph { code: nav.modelData.code; color: nav.current ? Theme.accent : nav.modelData.col; size: 16 }
                                        Text { text: nav.modelData.label; color: nav.current ? Theme.text : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.fontLg
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
