.pragma library

// Idle timeouts in effect. s holds the Settings values (minutes, 0 = never; idleDimSec in seconds).
// The battery set applies only when it is switched on and the machine runs on battery.
function effective(s, onBattery) {
    var bat = !!(s.idleBatterySeparate && onBattery)
    var lock = bat ? s.idleBatteryLockMin : s.idleLockMin
    var off = bat ? s.idleBatteryScreenOffMin : s.idleScreenOffMin
    var suspend = bat ? s.idleBatterySuspendMin : s.idleSuspendMin
    return { battery: bat, lock: lock, off: off, suspend: suspend, dimAt: dimAt(lock, off, s.idleDimSec) }
}

// Seconds of idle after which the screen dims: idleDimSec before the first of lock / screen off,
// but never in the first half of that wait. 0 = no dimming.
function dimAt(lockMin, offMin, dimSec) {
    var first = 0
    if (lockMin > 0) first = lockMin
    if (offMin > 0 && (first === 0 || offMin < first)) first = offMin
    if (first === 0 || !(dimSec > 0)) return 0
    var t = first * 60
    return Math.max(Math.ceil(t / 2), t - dimSec)
}

function minLabel(m) { return m === 0 ? "Never" : (m >= 60 ? (m / 60) + " h" : m + " min") }
function secLabel(s) { return s === 0 ? "Off" : (s >= 60 ? (s / 60) + " min" : s + " s") }
