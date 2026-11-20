import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import qs.components
import qs.modules.panels

// One bar per monitor: left widgets, centre island (clock / OSD / now playing), right widgets,
// and the dropdown attached to each widget. Widget order and visibility come from Settings.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    // the bar takes the keyboard only while one of its dropdowns is open (text fields, Esc, arrows)
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property string sn: screen.name
    property var islands: ({})
    function register(name, item) { var m = Object.assign({}, islands); m[name] = item; islands = m }
    Component.onCompleted: Ui.registerBar(sn, bar)
    function isOpen(name) { return Sys.openPopup === name && Sys.openScreen === sn }

    Component {
        id: widgetFactory
        Loader {
            id: ld
            required property string modelData
            readonly property string wid: modelData
            visible: Settings.shown(wid) && (item ? item.wanted !== false : true)
            sourceComponent: ({ notifications: wNotif, clipboard: wClip, workspaces: wWs, cava: wCava, mic: wMic, media: wMedia, appearance: wAppear,
                                volume: wVol, wifi: wWifi, bluetooth: wBt, battery: wBat, brightness: wBrightness, power: wPower })[wid] || null
            onLoaded: bar.register(wid, item)
        }
    }

    Item {
        anchors { fill: parent; topMargin: Theme.barMargin; bottomMargin: Theme.barMargin; leftMargin: Theme.barSideInset; rightMargin: Theme.barSideInset }

        Rectangle {
            visible: Settings.barStyle !== "pills" && Theme.styleMode === "solid"
            anchors.fill: parent
            radius: Theme.windowRounding
            color: Theme.surface
            border.width: Theme.barSurfaceBorderWidth
            border.color: Theme.barSurfaceBorderColor
        }

        Rectangle {
            visible: Settings.barStyle !== "pills" && Theme.styleMode === "glass"
            anchors.fill: parent
            radius: Theme.windowRounding
            antialiasing: true
            border.width: Theme.barSurfaceBorderWidth
            border.color: Theme.barSurfaceBorderColor
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.glassPopTop }
                GradientStop { position: 1; color: Theme.glassPopBottom }
            }
        }

        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: Theme.pillGap
            Repeater { model: Settings.leftOrder; delegate: widgetFactory }
        }

        CenterIsland {
            id: clockIsland
            anchors.centerIn: parent
            bar: bar
            Component.onCompleted: bar.register("calendar", clockIsland)
        }

        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Theme.pillGap
            layoutDirection: Qt.LeftToRight
            Repeater { model: Settings.rightOrder; delegate: widgetFactory }
        }
    }

    // ------------------------------------------------------------- widgets
    // Icons are Material Symbols names from Theme.sym; Theme.barTone() applies the
    // colourful / monochrome icon style from Settings. Semantic colours (muted, alert) always apply.
    Component { id: wNotif; BarButton {
        icon: Settings.dnd ? "bellOff" : "bell"            // unread state is the badge
        iconColor: Theme.barTone(Theme.pink)
        badge: Settings.dnd ? 0 : Notifs.history.length
        tooltip: "Notifications"
        active: bar.isOpen("notifications")
        onClicked: Sys.toggle("notifications", bar.sn)
        onRightClicked: Sys.setDnd(!Settings.dnd)
    } }
    Component { id: wClip; BarButton {
        icon: "clipboard"; iconColor: Theme.barTone(Theme.purple); tooltip: "Clipboard"
        active: bar.isOpen("clipboard")
        onClicked: Sys.toggle("clipboard", bar.sn)
    } }
    Component { id: wWs; Island { backgroundEnabled: Settings.barStyle === "pills"; WorkspaceDots { screenName: bar.sn } } }
    Component { id: wCava; BarButton {
        implicitWidth: 112
        width: 112
        iconColor: Theme.barTone(Theme.accent)
        tooltip: "Audio spectrum · click for music controls"
        active: bar.isOpen("cava")
        onClicked: Sys.toggle("cava", bar.sn)
        Repeater {
            model: Cava.level
            delegate: Rectangle {
                required property real modelData
                required property int index
                readonly property real barHeight: 2 + modelData * 17
                x: 12 + index * ((112 - 24) / Cava.barCount)
                y: (parent.height - height) / 2
                width: 2.2
                height: barHeight
                radius: width / 2
                antialiasing: true
                color: Qt.alpha(Theme.barTone(Theme.accent), 0.58 + modelData * 0.42)
                Behavior on height {
                    NumberAnimation { duration: 42; easing.type: Easing.OutCubic }
                }
            }
        }
    } }
    Component { id: wMic; BarButton {
        property bool wanted: Sys.micMuted
        icon: "micOff"; iconColor: Theme.red; tooltip: "Microphone muted"
        onClicked: Sys.toggleMic()
    } }
    Component { id: wMedia; BarButton {
        property bool wanted: !!Sys.player && Settings.islandMedia === false
        icon: Sys.mediaPlaying ? "pause" : "play"; iconColor: Theme.barTone(Theme.green); tooltip: "Play / pause"
        onClicked: Sys.mediaPlayPause()
        onRightClicked: Sys.mediaNext()
    } }
    Component { id: wAppear; BarButton {
        icon: "settings"; iconColor: Theme.barTone(Theme.purple); tooltip: "Settings"
        active: Ui.settingsOpen
        onClicked: Ui.openSettings("appearance")
    } }
    Component { id: wVol; BarButton {
        icon: Theme.volumeSym(Sys.volume, Sys.muted)
        iconColor: Sys.muted ? Theme.red : Theme.barTone(Theme.cyan)
        tooltip: "Volume " + Sys.volume + "%"
        active: bar.isOpen("volume")
        onClicked: Sys.toggle("volume", bar.sn)
        onRightClicked: Sys.toggleMute()
        onWheel: delta => Sys.setVolume(Math.max(0, Math.min(100, Sys.volume + (delta > 0 ? 3 : -3))))
    } }
    Component { id: wWifi; BarButton {
        icon: Sys.wiredConnected && Sys.ssid === "" ? "lan" : Theme.wifiSym(Sys.wifiOn, Sys.ssid, Sys.wifiSignal)
        iconTrack: Sys.ssid !== "" ? "wifi" : ""
        iconColor: (!Sys.wifiOn && !Sys.wiredConnected) ? Theme.red : Theme.barTone(Theme.cyan)
        tooltip: Sys.ssid !== "" ? Sys.ssid : "Wi-Fi"
        active: bar.isOpen("wifi")
        onClicked: Sys.toggle("wifi", bar.sn)
    } }
    Component { id: wBt; BarButton {
        icon: !Sys.btOn ? "btOff" : (Sys.btDevice !== "" ? "btConnected" : "bt")
        iconColor: Sys.btOn ? Theme.barTone(Theme.blue) : Theme.muted
        tooltip: "Bluetooth"
        active: bar.isOpen("bluetooth")
        onClicked: Sys.toggle("bluetooth", bar.sn)
    } }
    Component { id: wBat; BarButton {
        property bool wanted: Sys.hasBattery || Sys.hasBacklight
        icon: Sys.hasBattery ? Theme.batterySym(Sys.batCap, Sys.batState) : "brightness"
        iconColor: !Sys.hasBattery ? Theme.barTone(Theme.yellow) : (Sys.batCap <= 15 ? Theme.red : (Sys.batCap <= 30 ? Theme.yellow : Theme.barTone(Theme.green)))
        label: Sys.hasBattery ? Sys.batCap + "%" : ""
        tooltip: "Battery"
        active: bar.isOpen("battery")
        onClicked: Sys.toggle("battery", bar.sn)
    } }
    Component { id: wBrightness; BarButton {
        property bool wanted: Sys.hasBacklight
        icon: "brightness"
        iconRotation: Sys.brightnessIconRotation
        iconColor: Theme.barTone(Theme.yellow)
        label: Sys.brightness + "%"
        tooltip: "Brightness"
        active: bar.isOpen("brightness")
        onClicked: Sys.toggle("brightness", bar.sn)
    } }
    Component { id: wPower; BarButton {
        icon: "power"; iconColor: Theme.barTone(Theme.pink); tooltip: "Power  (right-click: About)"
        active: bar.isOpen("power")
        onClicked: Sys.toggle("power", bar.sn)
        onRightClicked: Ui.openSettings("about")
    } }

    // ------------------------------------------------------------- dropdowns
    Dropdown { barWindow: bar; target: bar.islands.notifications || null; name: "notifications"; panelWidth: 390; NotificationsPanel {} }
    Dropdown { id: clipDrop; barWindow: bar; target: bar.islands.clipboard || null; name: "clipboard"; panelWidth: 400; ClipboardPanel { open: clipDrop.open } }
    Dropdown { id: calDrop; barWindow: bar; target: clockIsland; name: "calendar"; panelWidth: 760; CalendarCard { now: Time.date; active: calDrop.open } MediaCard {} }
    Dropdown { barWindow: bar; target: bar.islands.volume || null; name: "volume"; panelWidth: 350; SoundPanel {} }
    Dropdown {
        barWindow: bar; target: bar.islands.cava || null; name: "cava"; panelWidth: 390
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.dropdownGap
            Heading {
                title: "Music"
                subtitle: Sys.player ? (Sys.player.trackTitle || Sys.player.identity || "Now playing") : "No music player is available"
            }
            MediaCard {}
        }
    }
    Dropdown { barWindow: bar; target: bar.islands.wifi || null; name: "wifi"; panelWidth: 380; WifiPanel {} }
    Dropdown { barWindow: bar; target: bar.islands.bluetooth || null; name: "bluetooth"; panelWidth: 380; BluetoothPanel {} }
    Dropdown { barWindow: bar; target: bar.islands.battery || null; name: "battery"; panelWidth: 340; BatteryPanel {} }
    Dropdown { barWindow: bar; target: bar.islands.brightness || null; name: "brightness"; panelWidth: 320; BrightnessPanel {} }
    PowerPanel { targetScreen: bar.screen }
}
