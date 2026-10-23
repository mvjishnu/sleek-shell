import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

Scope {
    id: guard
    required property var ctl

    property bool testArmed: false
    property bool screenOffByUs: false
    property bool sleepPending: false
    property string lastEvent: ""
    property double lastEventAt: 0
    readonly property bool sleepInhibitorActive: inhibitor.running

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

    function disp(expr) { Quickshell.execDetached(["hyprctl", "dispatch", expr]) }

    function lockNow(reason) {
        if (ctl.locked) return
        note("lock (" + reason + (testArmed ? ", test" : "") + ")")
        ctl.begin(testArmed)
    }

    function screenOff() {
        if (screenOffByUs) return
        screenOffByUs = true
        note("screen off" + (testArmed ? " (test)" : ""))
        disp("hl.dsp.dpms(\"off\")")
        if (testArmed) screenBack.restart()
    }

    function screenOn() {
        screenBack.stop()
        if (!screenOffByUs) return
        screenOffByUs = false
        note("screen on")
        disp("hl.dsp.dpms(\"on\")")
    }

    IdleMonitor {
        id: lockIdle
        enabled: Settings.idleLockMin > 0
        timeout: Math.max(1, Settings.idleLockMin) * 60
        respectInhibitors: Settings.idleRespectInhibitors
        onIsIdleChanged: if (isIdle) guard.lockNow("idle " + Settings.idleLockMin + " min")
    }

    IdleMonitor {
        id: screenIdle
        enabled: Settings.idleScreenOffMin > 0
        timeout: Math.max(1, Settings.idleScreenOffMin) * 60
        respectInhibitors: Settings.idleRespectInhibitors
        onIsIdleChanged: isIdle ? guard.screenOff() : guard.screenOn()
    }

    IdleMonitor {
        id: suspendIdle
        enabled: Settings.idleSuspendMin > 0
        timeout: Math.max(1, Settings.idleSuspendMin) * 60
        respectInhibitors: Settings.idleRespectInhibitors
        onIsIdleChanged: {
            if (!isIdle) return
            if (guard.testArmed) { guard.note("suspend skipped (test)"); return }
            guard.note("suspend (idle " + Settings.idleSuspendMin + " min)")
            Quickshell.execDetached(["systemctl", "suspend"])
        }
    }

    Timer { id: screenBack; interval: 4000; onTriggered: guard.screenOn() }
    Timer { id: testExpiry; interval: 180000; onTriggered: { guard.testArmed = false; guard.note("test mode ended") } }

    Process {
        id: inhibitor
        running: Settings.lockBeforeSleep && !guard.sleepPending
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
            if (!Settings.lockBeforeSleep) return
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
                lock: { enabled: lockIdle.enabled, timeout: lockIdle.timeout, idle: lockIdle.isIdle },
                screenOff: { enabled: screenIdle.enabled, timeout: screenIdle.timeout, idle: screenIdle.isIdle, off: guard.screenOffByUs },
                suspend: { enabled: suspendIdle.enabled, timeout: suspendIdle.timeout, idle: suspendIdle.isIdle },
                respectInhibitors: Settings.idleRespectInhibitors,
                lockBeforeSleep: Settings.lockBeforeSleep, sleepInhibitor: inhibitor.running,
                logindWatch: logind.running, session: guard.sessionPath,
                locked: guard.ctl.locked, test: guard.testArmed,
                lastEvent: guard.lastEvent, lastEventAgoMs: guard.lastEventAt ? Date.now() - guard.lastEventAt : -1
            })
        }
        function test(): void { guard.testArmed = true; testExpiry.restart(); guard.note("test mode armed") }
        function untest(): void { guard.testArmed = false; testExpiry.stop(); guard.note("test mode ended") }
    }
}
