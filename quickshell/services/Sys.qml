pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import Quickshell.Networking

// Shared system state + commands. Everything the bar and dropdowns read lives here.
//
// Sleek Shell: state is event driven through Quickshell's native services (PipeWire, UPower,
// power-profiles-daemon, BlueZ, NetworkManager, MPRIS) instead of polling scripts/status.sh,
// which took ~8 s per run and was re-run every 2.5–8 s. Nothing here spawns a process while idle.
// Wi-Fi listing/connecting (wifi-*.sh) and Bluetooth pairing (bt.py, which brings its own agent)
// keep their proven helpers and only run on demand.
Singleton {
    id: sys

    signal lockRequested()
    signal osd(string kind, real value, bool muted)
    property real clockW: 200
    property bool lockHideClock: false

    // ---- which dropdown is open (one at a time, on one screen) ----
    property string openPopup: ""
    property string openScreen: ""

    function toggle(name, screenName) {
        if (openPopup === name && openScreen === screenName) { close(); return }
        openPopup = name
        openScreen = screenName
        if (name === "wifi") { if (!wifiBusy) setWifiMsg("", false); wifiPending = ""; scanWifi() }
        else if (name === "bluetooth") { btMsg = ""; btInfo = ""; probeBtManager(); if (btOn) setDiscovering(true) }
        else if (name === "clipboard") loadClipboard()
        else if (name === "battery") readBrightness()
    }
    function close() {
        if (openPopup === "wifi") { stopWifiScan(); wifiPending = "" }
        openPopup = ""
        setDiscovering(false)
    }

    // ---- helpers ----
    function run(args) { Quickshell.execDetached(args) }
    function sh(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }
    function later(fn, ms) { delayed.fn = fn; delayed.interval = ms; delayed.restart() }
    function refresh() { readBrightness() }
    Timer { id: delayed; property var fn: null; onTriggered: if (fn) fn() }

    // =========================================================================
    //  Audio — PipeWire
    // =========================================================================
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [sys.sink, sys.source] }
    readonly property bool audioReady: !!(sink && sink.ready && sink.audio)
    readonly property int volume: audioReady ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: audioReady ? sink.audio.muted : false
    readonly property bool micMuted: !!(source && source.ready && source.audio) ? source.audio.muted : false
    readonly property string sinkName: sink ? (sink.description || sink.nickname || sink.name) : ""

    function setVolume(v) {
        if (!audioReady) return
        sink.audio.muted = false
        sink.audio.volume = Math.max(0, Math.min(100, v)) / 100
    }
    function toggleMute() { if (audioReady) sink.audio.muted = !sink.audio.muted }
    function toggleMic() { if (source && source.audio) source.audio.muted = !source.audio.muted }

    property bool audioSettled: false
    Timer { running: sys.audioReady; interval: 1500; onTriggered: sys.audioSettled = true }
    Connections {
        target: sys.audioReady ? sys.sink.audio : null
        function onVolumeChanged() { if (sys.audioSettled && sys.openPopup !== "volume") sys.osd("volume", sys.volume, sys.muted) }
        function onMutedChanged() { if (sys.audioSettled && sys.openPopup !== "volume") sys.osd("volume", sys.volume, sys.muted) }
    }

    // =========================================================================
    //  Battery + power profiles — UPower / power-profiles-daemon
    // =========================================================================
    readonly property var batDev: UPower.displayDevice
    readonly property bool hasBattery: !!(batDev && batDev.isLaptopBattery && batDev.isPresent)
    readonly property int batCap: hasBattery ? Math.round(batDev.percentage * 100) : 0
    readonly property string batState: {
        if (!hasBattery) return ""
        switch (batDev.state) {
        case UPowerDeviceState.Charging: return "Charging"
        case UPowerDeviceState.FullyCharged: return "Full"
        case UPowerDeviceState.Discharging: return "Discharging"
        case UPowerDeviceState.PendingCharge: return "Not charging"
        default: return UPower.onBattery ? "Discharging" : "Full"
        }
    }
    readonly property string batTime: {
        if (!hasBattery) return ""
        var s = batState === "Charging" ? batDev.timeToFull : (batState === "Discharging" ? batDev.timeToEmpty : 0)
        if (!s || s <= 0) return ""
        var h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60)
        return (h > 0 ? h + " h " : "") + m + " min" + (batState === "Charging" ? " to full" : " left")
    }
    readonly property string profile: {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver: return "power-saver"
        case PowerProfile.Balanced: return "balanced"
        case PowerProfile.Performance: return "performance"
        default: return ""
        }
    }
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    function setProfile(p) {
        if (p === "power-saver") PowerProfiles.profile = PowerProfile.PowerSaver
        else if (p === "balanced") PowerProfiles.profile = PowerProfile.Balanced
        else if (p === "performance" && hasPerformance) PowerProfiles.profile = PowerProfile.Performance
    }

    // =========================================================================
    //  Brightness — sysfs reads (no process); writes via brightnessctl
    // =========================================================================
    property string backlightDevice: ""          // e.g. "amdgpu_bl2"; empty = first device
    property bool hasBacklight: false
    property int brightness: 50
    property int maxBrightness: 1
    Process {
        id: blProbe
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight 2>/dev/null | head -n1"]
        stdout: StdioCollector { onStreamFinished: { var d = text.trim(); if (sys.backlightDevice === "") sys.backlightDevice = d; sys.hasBacklight = d !== "" } }
    }
    FileView { id: blMax; path: sys.backlightDevice ? "/sys/class/backlight/" + sys.backlightDevice + "/max_brightness" : ""; printErrors: false
        onLoaded: sys.maxBrightness = Math.max(1, parseInt(text()) || 1) }
    FileView { id: blCur; path: sys.backlightDevice ? "/sys/class/backlight/" + sys.backlightDevice + "/brightness" : ""; printErrors: false
        onLoaded: if (!brTimer.running) sys.brightness = Math.max(1, Math.min(100, Math.round((parseInt(text()) || 0) * 100 / sys.maxBrightness))) }
    function readBrightness() { if (hasBacklight) { blMax.reload(); blCur.reload() } }
    Timer { interval: 1500; repeat: true; running: sys.openPopup === "battery"; onTriggered: sys.readBrightness() }
    function setBrightness(v) {
        brightness = Math.max(1, Math.round(v))
        brTimer.restart()
    }
    Timer {
        id: brTimer; interval: 60
        onTriggered: {
            var a = ["brightnessctl"]
            if (sys.backlightDevice !== "") a.push("-d", sys.backlightDevice)
            a.push("set", sys.brightness + "%")
            sys.run(a)
        }
    }
    // called by the brightness keys (quickshell ipc call osd brightness) for the island OSD
    function brightnessKey() { osdBr.restart() }
    Timer { id: osdBr; interval: 40; onTriggered: { sys.readBrightness(); osdBr2.restart() } }
    Timer { id: osdBr2; interval: 30; onTriggered: sys.osd("brightness", sys.brightness, false) }

    // =========================================================================
    //  Bluetooth — BlueZ
    // =========================================================================
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btAvailable: !!btAdapter
    readonly property bool btOn: btAvailable && btAdapter.enabled
    readonly property bool btScanning: btAvailable && btAdapter.discovering
    readonly property var btDevices: btAvailable ? btAdapter.devices.values : []
    readonly property var btList: btDevices.map(function (d) {
        return { mac: d.address, name: d.name || d.deviceName || d.address, paired: d.paired || d.bonded, connected: d.connected,
                 rssi: 0, icon: d.icon || "", battery: d.batteryAvailable ? Math.round(d.battery * 100) : -1, busy: d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting, dev: d }
    })
    readonly property string btDevice: {
        for (var i = 0; i < btDevices.length; ++i) if (btDevices[i].connected) return btDevices[i].name || btDevices[i].address
        return ""
    }
    property string btMsg: ""
    property string btInfo: ""
    property bool btManager: false

    function devByMac(mac) { for (var i = 0; i < btDevices.length; ++i) if (btDevices[i].address === mac) return btDevices[i]; return null }
    function toggleBt() { btMsg = ""; if (btAvailable) btAdapter.enabled = !btAdapter.enabled }
    function setDiscovering(on) { if (btAvailable && btAdapter.enabled && btAdapter.discovering !== on) btAdapter.discovering = on }
    function rescanBt() { setDiscovering(false); setDiscovering(true) }
    function scanBt() { if (btOn) setDiscovering(true) }
    function btConnect(mac) { btMsg = ""; var d = devByMac(mac); if (d) d.connect(); else btMsg = "Device not found" }
    function btDisconnect(mac) { btMsg = ""; var d = devByMac(mac); if (d) d.disconnect() }
    function btRemove(mac) { btMsg = ""; var d = devByMac(mac); if (d) d.forget() }
    function btPair(mac) {     // bt.py registers a pairing agent for PIN / passkey prompts
        btMsg = "Pairing…"; btInfo = ""
        btCtl.command = ["python3", Quickshell.shellPath("scripts/bt.py"), "pair", mac]
        btCtl.running = true
    }
    Process {
        id: btCtl
        stdout: StdioCollector {
            onStreamFinished: {
                var res = {}
                try { res = JSON.parse(text) } catch (e) { res = {} }
                if (res.error) sys.btMsg = res.error
                else if (res.info) { sys.btInfo = res.info; sys.btMsg = "" }
                else sys.btMsg = ""
            }
        }
        onExited: code => { if (code !== 0 && (sys.btMsg === "" || sys.btMsg === "Pairing…")) sys.btMsg = "Pairing failed" }
    }
    function probeBtManager() { if (!btManagerProc.running) btManagerProc.running = true }
    Process {
        id: btManagerProc
        command: ["sh", "-c", "command -v blueman-manager >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector { onStreamFinished: sys.btManager = text.trim() === "yes" }
    }

    // =========================================================================
    //  Wi-Fi — NetworkManager over D-Bus (Quickshell.Networking)
    // =========================================================================
    readonly property var wifiDev: {
        var v = Networking.devices.values
        for (var i = 0; i < v.length; ++i) if (v[i].type === DeviceType.Wifi) return v[i]
        return null
    }
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property bool wifiAvailable: wifiDev !== null
    readonly property string ssid: {
        if (!wifiDev || !wifiDev.connected || !wifiDev.networks) return ""
        var n = wifiDev.networks.values
        for (var i = 0; i < n.length; ++i) if (n[i] && n[i].connected) return n[i].name
        return ""
    }
    readonly property int wifiSignal: {
        if (!wifiDev || !wifiDev.networks || !wifiDev.networks.values) return 0
        var n = wifiDev.networks.values
        for (var i = 0; i < n.length; ++i) if (n[i] && n[i].connected) { var v = Number(n[i].signalStrength); return isNaN(v) ? 0 : Math.round(v * 100) }
        return 0
    }
    readonly property bool wiredConnected: {
        var v = Networking.devices.values
        for (var i = 0; i < v.length; ++i) if (v[i].type === DeviceType.Wired && v[i].connected) return true
        return false
    }

    // Networks come straight from NetworkManager over D-Bus (Quickshell.Networking): no nmcli,
    // no password on any command line, saved networks connect without asking again.
    readonly property var wifiList: {
        if (!wifiOn || !wifiDev || !wifiDev.networks) return []
        var v = wifiDev.networks.values, best = {}
        for (var i = 0; i < v.length; ++i) {
            var n = v[i]
            if (!n || !n.name) continue
            var sig = Math.round((Number(n.signalStrength) || 0) * 100)
            var o = { ssid: n.name, signal: sig, secure: n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe,
                      enterprise: n.security === WifiSecurityType.Wpa2Eap || n.security === WifiSecurityType.WpaEap || n.security === WifiSecurityType.Wpa3SuiteB192,
                      active: n.connected, known: n.known, busy: n.stateChanging, net: n }
            var b = best[n.name]
            if (!b || (o.active && !b.active) || (o.active === b.active && o.signal > b.signal)) best[n.name] = o
        }
        var out = Object.keys(best).map(function (k) { return best[k] })
        out.sort(function (a, b) { return (b.active - a.active) || (b.known - a.known) || (b.signal - a.signal) || a.ssid.localeCompare(b.ssid) })
        return out
    }
    readonly property bool wifiBusy: wifiTarget !== null
    property bool wifiScanning: false
    property string wifiMsg: ""
    property bool wifiMsgOk: false
    property string wifiPending: ""          // SSID waiting for a password
    property string wifiPendingNote: ""      // why we are asking (e.g. saved password rejected)
    property var wifiTarget: null            // network we are connecting to right now
    property string wifiTargetName: ""
    property bool wifiTargetUsedPsk: false

    function wifiNet(ssid) {
        for (var i = 0; i < wifiList.length; ++i) if (wifiList[i].ssid === ssid) return wifiList[i]
        return null
    }
    function setWifiMsg(msg, ok) { wifiMsg = msg; wifiMsgOk = !!ok }

    function scanWifi() {
        if (!wifiDev || !wifiOn) return
        wifiDev.scannerEnabled = true
        if (wifiList.length === 0) { wifiScanning = true; wifiScanDone.restart() }
    }
    function rescanWifi() {
        if (!wifiDev || !wifiOn) return
        wifiScanning = true
        wifiDev.scannerEnabled = false
        later(function () { if (sys.wifiDev) sys.wifiDev.scannerEnabled = true }, 50)
        wifiScanDone.restart()
    }
    function stopWifiScan() { if (wifiDev) wifiDev.scannerEnabled = false; wifiScanning = false }
    Timer { id: wifiScanDone; interval: 4000; onTriggered: { sys.wifiScanning = false; interval = 4000 } }
    onWifiListChanged: if (wifiScanning && wifiList.length > 0 && wifiScanDone.interval > 1500) { wifiScanDone.interval = 1200; wifiScanDone.restart() }

    function toggleWifi() {
        setWifiMsg("", false)
        wifiPending = ""
        Networking.wifiEnabled = !wifiOn
        if (!wifiOn) later(function () { sys.scanWifi() }, 1200)
    }

    // Click on a network: connected -> nothing, saved/open -> connect now, new secured -> ask.
    function connectWifi(ssid) {
        var e = wifiNet(ssid)
        if (!e || e.active || wifiBusy) return
        setWifiMsg("", false)
        if (e.enterprise && !e.known) { setWifiMsg("Enterprise (802.1X) networks need Network settings", false); return }
        if (e.known || !e.secure) { beginWifi(e, ""); return }
        wifiPendingNote = ""
        wifiPending = ssid
    }
    function submitWifiPassword(psk) {
        var e = wifiNet(wifiPending)
        if (!e) { setWifiMsg("“" + wifiPending + "” is out of range", false); wifiPending = ""; return }
        if (psk.length < 8 || psk.length > 63) { setWifiMsg("Wi-Fi passwords are 8–63 characters", false); return }
        wifiPending = ""
        beginWifi(e, psk)
    }
    function cancelWifiPassword() { wifiPending = ""; wifiPendingNote = ""; setWifiMsg("", false) }
    function beginWifi(e, psk) {
        wifiTargetName = e.ssid
        wifiTargetUsedPsk = psk !== ""
        wifiTarget = e.net
        wifiTimeout.restart()
        if (psk !== "") e.net.connectWithPsk(psk)
        else e.net.connect()
    }
    function endWifi(msg, ok) {
        wifiTimeout.stop()
        wifiTarget = null
        setWifiMsg(msg, ok)
    }
    function disconnectWifi() {
        for (var i = 0; i < wifiList.length; ++i) if (wifiList[i].active) { wifiList[i].net.disconnect(); setWifiMsg("Disconnected from " + wifiList[i].ssid, true); return }
    }
    function forgetWifi(ssid) {
        var e = wifiNet(ssid)
        if (!e || !e.known) return
        e.net.forget()
        setWifiMsg("Forgot " + ssid, true)
    }
    function wifiFailText(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets: return "Wrong password"
        case ConnectionFailReason.WifiAuthTimeout: return "Wrong password or the network didn't answer"
        case ConnectionFailReason.WifiClientFailed: return "Couldn't authenticate"
        case ConnectionFailReason.WifiClientDisconnected: return "The network dropped the connection"
        case ConnectionFailReason.WifiNetworkLost: return "Network went out of range"
        default: return "Couldn't connect"
        }
    }
    Connections {
        target: sys.wifiTarget
        ignoreUnknownSignals: true
        function onConnectedChanged() { if (sys.wifiTarget && sys.wifiTarget.connected) sys.endWifi("Connected to " + sys.wifiTargetName, true) }
        function onConnectionFailed(reason) {
            var name = sys.wifiTargetName, usedPsk = sys.wifiTargetUsedPsk
            var authProblem = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout || reason === ConnectionFailReason.WifiClientFailed
            sys.endWifi(sys.wifiFailText(reason) + (name ? " — " + name : ""), false)
            var e = sys.wifiNet(name)
            if (authProblem && e && e.secure && !e.enterprise) {
                sys.wifiPendingNote = usedPsk ? "That password didn't work. Try again." : "The saved password didn't work. Enter it again."
                sys.wifiPending = name
            }
        }
    }
    Timer {
        id: wifiTimeout
        interval: 30000
        onTriggered: if (sys.wifiTarget) sys.endWifi("Timed out connecting to " + sys.wifiTargetName, false)
    }

    // =========================================================================
    //  Media — MPRIS
    // =========================================================================
    readonly property var players: Mpris.players.values
    readonly property var player: {
        var p = players
        for (var i = 0; i < p.length; ++i) if (p[i].isPlaying) return p[i]
        return p.length ? p[0] : null
    }
    readonly property bool mediaPlaying: !!player && player.isPlaying
    function mediaPlayPause() { if (player && player.canTogglePlaying) player.togglePlaying() }
    function mediaNext() { if (player && player.canGoNext) player.next() }
    function mediaPrev() { if (player && player.canGoPrevious) player.previous() }

    // =========================================================================
    //  Clipboard — cliphist, read on demand
    // =========================================================================
    property var clipboard: []
    function loadClipboard() { if (!clipProc.running) clipProc.running = true }
    function copyClip(id) { run(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "_", id]); close() }
    function wipeClip() { run(["cliphist", "wipe"]); clipboard = [] }
    Process {
        id: clipProc
        command: ["sh", "-c", "cliphist list 2>/dev/null | head -n 200"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                text.split("\n").forEach(function (l) {
                    if (!l) return
                    var tab = l.indexOf("\t")
                    var body = tab >= 0 ? l.slice(tab + 1) : l
                    out.push({ id: tab >= 0 ? l.slice(0, tab) : "", text: body.replace(/\s+/g, " ").trim(), isImage: body.indexOf("[[ binary data") === 0 })
                })
                sys.clipboard = out
            }
        }
    }

    // =========================================================================
    //  Notifications — kept here for existing callers; the server lives in Notifs.qml
    // =========================================================================
    readonly property var notifs: Notifs.history
    readonly property bool dnd: Settings.dnd
    function setDnd(v) { Settings.set("dnd", !!v) }
    function dismissNotif(id) { Notifs.dismiss(id) }
    function clearNotifs() { Notifs.clear() }

    // ---- IPC for keys and scripts ----
    IpcHandler {
        target: "media"
        function playPause(): void { sys.mediaPlayPause() }
        function next(): void { sys.mediaNext() }
        function previous(): void { sys.mediaPrev() }
    }
    IpcHandler {
        target: "osd"
        function brightness(): void { sys.brightnessKey() }
        function volume(): void { sys.osd("volume", sys.volume, sys.muted) }
    }

    Component.onCompleted: probeBtManager()
}
