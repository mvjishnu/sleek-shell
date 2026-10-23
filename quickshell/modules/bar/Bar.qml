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
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell"
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
            sourceComponent: ({ notifications: wNotif, clipboard: wClip, workspaces: wWs, mic: wMic, media: wMedia, appearance: wAppear,
                                volume: wVol, wifi: wWifi, bluetooth: wBt, battery: wBat, power: wPower })[wid] || null
            onLoaded: bar.register(wid, item)
        }
    }

    Item {
        anchors { fill: parent; topMargin: Theme.barMargin; bottomMargin: Theme.barMargin; leftMargin: Theme.barSideInset; rightMargin: Theme.barSideInset }

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
        iconColor: Settings.dnd ? Theme.muted : Theme.barTone(Theme.yellow)
        badge: Settings.dnd ? 0 : Notifs.history.length
        tooltip: "Notifications"
        active: bar.isOpen("notifications")
        onClicked: Sys.toggle("notifications", bar.sn)
        onRightClicked: Sys.setDnd(!Settings.dnd)
    } }
    Component { id: wClip; BarButton {
        icon: "clipboard"; iconColor: Theme.barTone(Theme.cyan); tooltip: "Clipboard"
        active: bar.isOpen("clipboard")
        onClicked: Sys.toggle("clipboard", bar.sn)
    } }
    Component { id: wWs; Island { WorkspaceDots { screenName: bar.sn } } }
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
        icon: "palette"; iconColor: Theme.barTone(Theme.blue); tooltip: "Appearance"
        active: bar.isOpen("appearance")
        onClicked: Sys.toggle("appearance", bar.sn)
        onRightClicked: Ui.openSettings("appearance")
    } }
    Component { id: wVol; BarButton {
        icon: Theme.volumeSym(Sys.volume, Sys.muted)
        iconColor: Sys.muted ? Theme.muted : Theme.barTone(Theme.pink)
        tooltip: "Volume " + Sys.volume + "%"
        active: bar.isOpen("volume")
        onClicked: Sys.toggle("volume", bar.sn)
        onRightClicked: Sys.toggleMute()
        onWheel: delta => Sys.setVolume(Math.max(0, Math.min(100, Sys.volume + (delta > 0 ? 3 : -3))))
    } }
    Component { id: wWifi; BarButton {
        icon: Sys.wiredConnected && Sys.ssid === "" ? "lan" : Theme.wifiSym(Sys.wifiOn, Sys.ssid, Sys.wifiSignal)
        iconTrack: Sys.ssid !== "" ? "wifi" : ""
        iconColor: !Sys.wifiOn && !Sys.wiredConnected ? Theme.muted : (Sys.ssid !== "" || Sys.wiredConnected ? Theme.barTone(Theme.cyan) : Theme.dim)
        tooltip: Sys.ssid !== "" ? Sys.ssid : "Wi-Fi"
        active: bar.isOpen("wifi")
        onClicked: Sys.toggle("wifi", bar.sn)
    } }
    Component { id: wBt; BarButton {
        icon: !Sys.btOn ? "btOff" : (Sys.btDevice !== "" ? "btConnected" : "bt")
        iconColor: Sys.btOn ? Theme.barTone(Theme.purple) : Theme.muted
        tooltip: "Bluetooth"
        active: bar.isOpen("bluetooth")
        onClicked: Sys.toggle("bluetooth", bar.sn)
    } }
    Component { id: wBat; BarButton {
        property bool wanted: Sys.hasBattery || Sys.hasBacklight
        icon: Sys.hasBattery ? Theme.batterySym(Sys.batCap, Sys.batState) : "brightness"
        iconColor: Sys.hasBattery ? (Sys.batCap < 30 || Sys.batState === "Charging" ? Theme.batteryColor(Sys.batCap, Sys.batState) : Theme.barTone(Theme.green)) : Theme.barTone(Theme.yellow)
        label: Sys.hasBattery ? Sys.batCap + "%" : ""
        tooltip: "Battery"
        active: bar.isOpen("battery")
        onClicked: Sys.toggle("battery", bar.sn)
    } }
    Component { id: wPower; BarButton {
        icon: "power"; iconColor: Theme.barTone(Theme.red); tooltip: "Power  (right-click: About)"
        active: bar.isOpen("power")
        onClicked: Sys.toggle("power", bar.sn)
        onRightClicked: Ui.openSettings("about")
    } }

    // ------------------------------------------------------------- dropdowns
    Dropdown { barWindow: bar; target: bar.islands.notifications || null; name: "notifications"; panelWidth: 390; NotificationsPanel {} }
    Dropdown { id: clipDrop; barWindow: bar; target: bar.islands.clipboard || null; name: "clipboard"; panelWidth: 400; ClipboardPanel { open: clipDrop.open } }
    Dropdown { id: calDrop; barWindow: bar; target: clockIsland; name: "calendar"; panelWidth: 360; CalendarCard { now: Time.date; active: calDrop.open } MediaCard {} }
    Dropdown { barWindow: bar; target: bar.islands.appearance || null; name: "appearance"; panelWidth: 384; Appearance {} }
    Dropdown { barWindow: bar; target: bar.islands.volume || null; name: "volume"; panelWidth: 350; SoundPanel {} }
    Dropdown { barWindow: bar; target: bar.islands.wifi || null; name: "wifi"; panelWidth: 380; WifiPanel {} }
    Dropdown { barWindow: bar; target: bar.islands.bluetooth || null; name: "bluetooth"; panelWidth: 380; BluetoothPanel {} }
    Dropdown { barWindow: bar; target: bar.islands.battery || null; name: "battery"; panelWidth: 340; BatteryPanel {} }
    Dropdown { id: powerDrop; barWindow: bar; target: bar.islands.power || null; name: "power"; panelWidth: 270; PowerPanel { open: powerDrop.open } }
}
