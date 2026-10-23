import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services
import qs.components
import qs.modules.lock

// Session lock. Start it with:  quickshell ipc call lock lock
// Safe test (auto-unlocks after 30 s):  quickshell ipc call lock test
Scope {
    id: lockCtl

    property string password: ""
    property string message: ""
    property bool failFlash: false
    property bool unlocking: false
    property bool testMode: false
    readonly property bool busy: pam.active
    readonly property bool locked: sessionLock.locked
    readonly property bool secure: sessionLock.secure
    readonly property real pillW: Sys.clockW
    signal failed()

    // 1) lift the bar's clock pill (the lock screen takes it over), 2) grab a picture of each screen, 3) lock,
    // so the lock drops out of the bar and the glass grows out of the desktop with no jump.
    function begin(test) {
        if (sessionLock.locked || shot.running || prep.running) return
        testMode = test
        password = ""
        message = ""
        unlocking = false
        failFlash = false
        prep.interval = Sys.openPopup !== "" ? 220 : 100   // give an open dropdown time to close first
        Sys.close()
        Sys.lockHideClock = true
        prep.restart()
    }

    function snapshot() {
        var cmds = ["rm -f /tmp/qs-lock-*.png"]
        Quickshell.screens.forEach(function(s) {
            cmds.push("grim -o '" + s.name + "' '/tmp/qs-lock-" + s.name + ".png' 2>/dev/null")
        })
        shot.command = ["sh", "-c", cmds.join("; ") + "; true"]
        shot.running = true
    }

    function engage() {
        sessionLock.locked = true
        if (testMode) failsafe.restart()
    }

    function submit() {
        if (password.length === 0 || pam.active || unlocking) return
        message = ""
        pam.start()
    }

    function fail() {
        message = "Incorrect password"
        failFlash = true
        failed()
        clearTimer.restart()
    }

    function succeed() {
        failsafe.stop()
        message = ""
        unlocking = true
        unlockTimer.restart()
    }

    // Let go of the lock without a password (used by the unlock IPC and by the
    // safe test mode).
    function release() {
        if (!sessionLock.locked) return
        failsafe.stop()
        message = ""
        unlocking = true
        unlockTimer.restart()
    }

    Timer { id: prep; onTriggered: lockCtl.snapshot() }
    Process { id: shot; onExited: lockCtl.engage() }
    Process { id: cleanup; command: ["sh", "-c", "rm -f /tmp/qs-lock-*.png"] }

    Timer { id: clearTimer; interval: 560; onTriggered: { lockCtl.password = ""; lockCtl.failFlash = false } }
    Timer { id: failsafe; interval: 30000; onTriggered: lockCtl.succeed() }
    Timer {
        id: unlockTimer
        interval: LockStyle.releaseDelay   // just long enough for the closing animation
        onTriggered: {
            Sys.lockHideClock = false   // bar pill is back underneath just as the lock lets go
            sessionLock.locked = false
            lockCtl.unlocking = false
            lockCtl.password = ""
            cleanup.running = true
        }
    }

    PamContext {
        id: pam
        config: "login"
        onPamMessage: { if (pam.responseRequired) pam.respond(lockCtl.password) }
        onCompleted: result => {
            if (result === PamResult.Success) lockCtl.succeed()
            else lockCtl.fail()
        }
        onError: lockCtl.fail()
    }

    IpcHandler {
        target: "lock"
        function lock(): void { lockCtl.begin(false) }
        function test(): void { lockCtl.begin(true) }
        // only releases the safe test lock; a real lock always needs the password
        function unlock(): void { if (lockCtl.testMode) lockCtl.release() }
        // visual checks, only while the safe test lock (`lock test`) is up; never touch PAM
        function testType(n: int): void { if (lockCtl.testMode && sessionLock.locked) lockCtl.password = "x".repeat(Math.max(0, Math.min(24, n))) }
        function testFail(): void { if (lockCtl.testMode && sessionLock.locked) { lockCtl.password = "xxxx"; lockCtl.fail() } }
    }

    Connections {
        target: Sys
        function onLockRequested() { lockCtl.begin(false) }
    }

    IdleGuard { ctl: lockCtl }

    WlSessionLock {
        id: sessionLock
        locked: false
        LockSurface { ctl: lockCtl }
    }
}
