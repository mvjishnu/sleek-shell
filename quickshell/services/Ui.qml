pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Shell-wide UI state: the settings window and which screen overlays open on.
Singleton {
    id: ui
    property bool settingsOpen: false
    property string settingsPage: "appearance"
    property var settingsScreen: null
    property bool dbgEntryFocus: false
    property var bars: ({})        // screen name -> Bar window (registered by each bar)
    function registerBar(name, bar) { var m = Object.assign({}, bars); m[name] = bar; bars = m }
    readonly property var pages: ["appearance", "styles", "motion", "bar", "windows", "wallpaper", "notifications", "lock", "launcher", "keyboard", "displays", "about"]

    function focusedScreen() {
        var s = Quickshell.screens, f = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        for (var i = 0; i < s.length; ++i) if (s[i].name === f) return s[i]
        return s.length ? s[0] : null
    }
    function openSettings(page) {
        if (page && pages.indexOf(page) >= 0) settingsPage = page
        settingsScreen = focusedScreen()
        settingsOpen = true
    }
    function closeSettings() { settingsOpen = false }
    function toggleSettings(page) {
        if (settingsOpen && (!page || page === settingsPage)) closeSettings()
        else openSettings(page)
    }

    GlobalShortcut { name: "settings-toggle"; description: "Sleek Shell settings"; onPressed: ui.toggleSettings() }
    // quickshell ipc call debug barGeometry eDP-1  -> logical rects of every bar widget (for layout tests)
    IpcHandler {
        target: "debug"
        function barGeometry(screen: string): string {
            var b = ui.bars[screen]
            if (!b) return "{}"
            var out = { screen: screen, items: [] }
            for (var k in b.islands) {
                var it = b.islands[k]
                if (!it || !it.visible || it.width <= 0) continue
                var p = it.mapToItem(null, 0, 0)
                var rec = { name: k, x: p.x, y: p.y, w: it.width, h: it.height }
                if (it.badge > 0) rec.badge = { x: p.x + it.width - 16, y: p.y + 2.5, w: 11, h: 11, icon: "" + it.iconColor }   // BarButton badge (8 px + ring), excluded from centring
                out.items.push(rec)
            }
            return JSON.stringify(out)
        }
        // quickshell ipc call debug state  -> open dropdown, Wi-Fi state (no secrets)
        function wifiPrompt(ssid: string): void { Sys.wifiPending = ssid }
        function wifiConnect(ssid: string): void { Sys.connectWifi(ssid) }
        function entryFocused(): bool { return ui.dbgEntryFocus }
        function state(): string {
            return JSON.stringify({ popup: Sys.openPopup, screen: Sys.openScreen, wifiOn: Sys.wifiOn, ssid: Sys.ssid, busy: Sys.wifiBusy,
                                    pending: Sys.wifiPending, note: Sys.wifiPendingNote, msg: Sys.wifiMsg, scanning: Sys.wifiScanning,
                                    networks: Sys.wifiList.map(function (n) { return n.ssid + (n.known ? "*" : "") + ":" + n.signal + (n.active ? ":on" : "") }) })
        }
    }
    IpcHandler {
        target: "settings"
        function toggle(): void { ui.toggleSettings() }
        function open(page: string): void { ui.openSettings(page) }
        function close(): void { ui.closeSettings() }
    }
}
