import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.modules.lock
import qs.services

// Independently designed Pixel-inspired session lock. Authentication stays
// with the system PAM login stack; the screen never accepts a bypass path.
Scope {
    id: lockCtl
    property string password: ""
    property string message: ""
    property string primaryScreen: ""
    property bool authenticating: pam.active
    property bool unlocking: false
    readonly property bool clock24h: Settings.lockClockFormat === "follow" ? Settings.clock24h : Settings.lockClockFormat === "24h"
    readonly property bool locked: sessionLock.locked
    readonly property bool secure: sessionLock.secure

    onLockedChanged: Sys.lockHideClock = locked
    Component.onCompleted: Sys.lockHideClock = locked

    function begin(_test) {
        if (sessionLock.locked || pam.active) return
        password = ""
        message = ""
        unlocking = false
        primaryScreen = Wm.focusedMon()
        Sys.lockHideClock = true
        sessionLock.locked = true
    }

    Connections {
        target: Sys
        function onLockRequested() { lockCtl.begin(false) }
    }

    function submit() {
        if (password.length === 0 || pam.active || unlocking) return
        message = ""
        pam.start()
    }

    function hourText(date) {
        var h = date.getHours()
        if (clock24h) return (h < 10 ? "0" : "") + h
        h %= 12
        return String(h === 0 ? 12 : h)
    }
    function meridiemText(date) { return clock24h ? "" : (date.getHours() < 12 ? "AM" : "PM") }

    function fail() {
        message = "That password didn’t work. Try again."
        password = ""
        clearMessage.restart()
    }

    function succeed() {
        message = ""
        unlocking = true
        password = ""
        releaseTimer.restart()
    }

    PamContext {
        id: pam
        config: "login"
        onPamMessage: { if (pam.responseRequired) pam.respond(lockCtl.password) }
        onCompleted: result => result === PamResult.Success ? lockCtl.succeed() : lockCtl.fail()
        onError: lockCtl.fail()
    }

    Timer { id: clearMessage; interval: 2600; onTriggered: lockCtl.message = "" }
    Timer {
        id: releaseTimer
        interval: 180
        onTriggered: {
            sessionLock.locked = false
            lockCtl.unlocking = false
            lockCtl.primaryScreen = ""
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { lockCtl.begin(false) }
        function isLocked(): bool { return lockCtl.locked }
        function isSecure(): bool { return lockCtl.secure }
        function clockFormat(): string {
            var now = new Date()
            return JSON.stringify({ mode: Settings.lockClockFormat, is24Hour: lockCtl.clock24h,
                                    hour: lockCtl.hourText(now), period: lockCtl.meridiemText(now) })
        }
    }

    IdleGuard { ctl: lockCtl }

    WlSessionLock {
        id: sessionLock
        locked: false
        PixelLockSurface { ctl: lockCtl }
    }
}
