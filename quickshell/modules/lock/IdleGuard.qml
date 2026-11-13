import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs.services
import "idle.js" as Idle

Scope {
    id: guard
    required property var ctl

    property bool testArmed: false
    property bool screenOffByUs: false
    property bool sleepPending: false
    property string lastEvent: ""
    property double lastEventAt: 0
    readonly property bool sleepInhibitorActive: inhibitor.running
    property bool dimmed: false
    property double idleSinceMs: 0
    property bool lockFired: false
    property bool screenOffFired: false
    property bool suspendFired: false
    property int idleElapsedSeconds: 0

    readonly property var eff: Idle.effective({
        idleLockMin: Settings.idleLockMin, idleScreenOffMin: Settings.idleScreenOffMin, idleSuspendMin: Settings.idleSuspendMin,
        idleBatterySeparate: Settings.idleBatterySeparate, idleBatteryLockMin: Settings.idleBatteryLockMin,
        idleBatteryScreenOffMin: Settings.idleBatteryScreenOffMin, idleBatterySuspendMin: Settings.idleBatterySuspendMin,
        idleDimSec: Settings.idleDimSec
    }, UPower.onBattery)
    onEffChanged: note("timeouts" + (eff.battery ? " (battery)" : "") + ": lock " + eff.lock + " min, screen off " + eff.off
                       + " min, suspend " + eff.suspend + " min, dim at " + eff.dimAt + " s")

    // Keep the Wayland monitors immutable. Quickshell 0.3.2 can stop updating
    // IdleMonitor.isIdle after timeout/enabled/respectInhibitors is changed and
    // its underlying notification is recreated. These two fixed 1-second
    // monitors provide activity state; the selected AC/battery deadlines are
    // evaluated here without changing either monitor's properties.
    readonly property bool inputIdle: Settings.idleRespectInhibitors ? idleWithInhibitors.isIdle : idleWithoutInhibitors.isIdle
    onInputIdleChanged: syncInputIdle()

    readonly property string sessionPath: {
        var id = Quickshell.env("XDG_SESSION_ID") || "", out = ""
        for (var i = 0; i < id.length; ++i) {
            var c = id[i]
            if (/[A-Za-z]/.test(c) || (/[0-9]/.test(c) && i > 0)) out += c
            else out += "_" + ("0" + c.charCodeAt(0).toString(16)).slice(-2)
        }
        return out === "" ? "" : "/org/freedesktop/login1/session/" + out
    }

    function note(msg) {
        lastEvent = msg
        lastEventAt = Date.now()
        console.info("idle: " + msg)
    }

    function syncInputIdle() {
        if (inputIdle) {
            if (idleSinceMs === 0) {
                idleSinceMs = Date.now()
                lockFired = false
                screenOffFired = false
                suspendFired = false
                idleElapsedSeconds = 0
                note("idle started" + (eff.battery ? " (battery)" : " (plugged in)"))
            }
            evaluateIdle()
            return
        }
        if (idleSinceMs === 0) return
        idleSinceMs = 0
        idleElapsedSeconds = 0
        lockFired = false
        screenOffFired = false
        suspendFired = false
        undim()
        screenOn()
        note("activity")
    }

    function evaluateIdle() {
        if (idleSinceMs === 0) return
        var elapsed = idleElapsedSeconds
        if (eff.dimAt > 0 && elapsed >= eff.dimAt) dim()
        if (eff.lock > 0 && elapsed >= eff.lock * 60 && !lockFired) {
            lockFired = true
            if (testArmed) note("lock skipped (test)")
            else lockNow("idle " + eff.lock + " min")
        }
        if (eff.off > 0 && elapsed >= eff.off * 60 && !screenOffFired) {
            screenOffFired = true
            screenOff()
        }
        if (eff.suspend > 0 && elapsed >= eff.suspend * 60 && !suspendFired) {
            suspendFired = true
            if (testArmed) note("suspend skipped (test)")
            else {
                if (!ctl.locked) lockNow("before idle suspend")
                note("suspend (idle " + eff.suspend + " min)")
                Quickshell.execDetached(["systemctl", "suspend"])
            }
        }
    }

    // Hyprland dispatchers are named arguments, not Lua expressions. Sending
    // `hl.dsp.dpms(...)` here is invalid from an IPC client and can leave the
    // monitor state out of sync with the idle monitor.
    function setDpms(state) { Quickshell.execDetached(["hyprctl", "dispatch", "dpms", state]) }

    function dim() {
        if (dimmed || ctl.locked || screenOffByUs) return
        dimmed = true
        note("dim" + (testArmed ? " (test)" : ""))
    }

    function undim() {
        if (!dimmed) return
        dimmed = false
        note("undim")
    }

    function lockNow(reason) {
        undim()
        if (testArmed) { note("lock skipped (test: " + reason + ")"); return }
        if (ctl.locked) return
        note("lock (" + reason + ")")
        ctl.begin(false)
    }

    function screenOff() {
        if (screenOffByUs) return
        if (testArmed) {
            note("screen-off test skipped; display left on")
            return
        }
        screenOffByUs = true
        undim()
        note("screen off")
        setDpms("off")
    }

    function screenOn() {
        if (!screenOffByUs) return
        screenOffByUs = false
        note("screen on")
        setDpms("on")
    }

    IdleMonitor {
        id: idleWithInhibitors
        enabled: true
        timeout: 1
        respectInhibitors: true
        onIsIdleChanged: if (Settings.idleRespectInhibitors) guard.syncInputIdle()
    }
    IdleMonitor {
        id: idleWithoutInhibitors
        enabled: true
        timeout: 1
        respectInhibitors: false
        onIsIdleChanged: if (!Settings.idleRespectInhibitors) guard.syncInputIdle()
    }
    Timer {
        // Deadlines only have one-second precision; avoid four wakeups a second.
        interval: 1000
        repeat: true
        running: guard.idleSinceMs > 0
        onTriggered: {
            guard.idleElapsedSeconds = Math.floor((Date.now() - guard.idleSinceMs) / 1000)
            guard.evaluateIdle()
        }
    }

    // Dimming: a click-through black layer on every monitor that fades in; any input fades it out.
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: shade
            required property var modelData
            screen: modelData
            visible: guard.dimmed || veil.opacity > 0
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sleek-shell-dim"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            Rectangle {
                id: veil
                anchors.fill: parent
                color: "black"
                opacity: guard.dimmed ? 0.6 : 0
                Behavior on opacity { NumberAnimation { duration: guard.dimmed ? 2000 : 150; easing.type: Easing.OutQuad } }
            }
        }
    }

    Timer { id: testExpiry; interval: 180000; onTriggered: { guard.testArmed = false; guard.note("test mode ended") } }

    Process {
        id: inhibitor
        running: !guard.sleepPending
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Sleek Shell",
                  "--why=Lock the screen before sleeping", "sleep", "infinity"]
    }

    function releaseSleep(why) {
        if (!sleepPending || !inhibitor.running) return
        sleepFallback.stop()
        note("sleep allowed (" + why + ")")
        inhibitor.running = false
    }
    Timer { id: sleepFallback; interval: 3000; onTriggered: guard.releaseSleep("timeout") }
    Timer { id: sleepSettle; interval: 250; onTriggered: guard.releaseSleep("locked") }
    Connections {
        target: guard.ctl
        function onSecureChanged() { if (guard.ctl.secure && guard.sleepPending) sleepSettle.restart() }
    }

    function onLogind(line) {
        if (line.indexOf(".Manager.PrepareForSleep (true") >= 0) {
            sleepPending = true
            note("preparing for sleep")
            if (ctl.locked && ctl.secure) sleepSettle.restart()
            else { lockNow("before sleep"); sleepFallback.restart() }
        } else if (line.indexOf(".Manager.PrepareForSleep (false") >= 0) {
            note("resumed")
            sleepPending = false
            screenOn()
        } else if (sessionPath !== "" && line.indexOf(sessionPath + ": org.freedesktop.login1.Session.Lock ") === 0) {
            lockNow("loginctl lock-session")
        }
    }

    Process {
        id: logind
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser { onRead: line => guard.onLogind(line) }
        onExited: logindRetry.restart()
    }
    Timer { id: logindRetry; interval: 5000; onTriggered: logind.running = true }

    IpcHandler {
        target: "idle"
        function status(): string {
            return JSON.stringify({
                onBattery: UPower.onBattery, battery: guard.eff.battery,
                inputIdle: guard.inputIdle, idleForSeconds: guard.idleElapsedSeconds,
                idleMonitor: {
                    timeoutSeconds: 1,
                    respectingInhibitors: idleWithInhibitors.isIdle,
                    ignoringInhibitors: idleWithoutInhibitors.isIdle,
                    respectInhibitorsSetting: Settings.idleRespectInhibitors
                },
                dim: { enabled: guard.eff.dimAt > 0, timeout: guard.eff.dimAt, idle: guard.inputIdle, dimmed: guard.dimmed },
                lock: { enabled: guard.eff.lock > 0, timeout: guard.eff.lock * 60, idle: guard.inputIdle, fired: guard.lockFired },
                screenOff: { enabled: guard.eff.off > 0, timeout: guard.eff.off * 60, idle: guard.inputIdle, off: guard.screenOffByUs, fired: guard.screenOffFired },
                suspend: { enabled: guard.eff.suspend > 0, timeout: guard.eff.suspend * 60, idle: guard.inputIdle, fired: guard.suspendFired },
                idleForSeconds: guard.idleElapsedSeconds,
                respectInhibitors: Settings.idleRespectInhibitors,
                lockBeforeSleep: true, sleepInhibitor: inhibitor.running,
                logindWatch: logind.running, session: guard.sessionPath,
                locked: guard.ctl.locked, test: guard.testArmed,
                lastEvent: guard.lastEvent, lastEventAgoMs: guard.lastEventAt ? Date.now() - guard.lastEventAt : -1
            })
        }
        function test(): void { guard.testArmed = true; testExpiry.restart(); guard.note("test mode armed") }
        function untest(): void { guard.testArmed = false; testExpiry.stop(); guard.note("test mode ended") }
    }
}
