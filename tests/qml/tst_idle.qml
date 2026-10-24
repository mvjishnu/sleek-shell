import QtQuick
import QtTest
import "../../quickshell/modules/lock/idle.js" as Idle

TestCase {
    name: "Idle"

    function base() {
        return { idleLockMin: 10, idleScreenOffMin: 15, idleSuspendMin: 0, idleDimSec: 30,
                 idleBatterySeparate: true, idleBatteryLockMin: 5, idleBatteryScreenOffMin: 10, idleBatterySuspendMin: 15 }
    }

    function test_plugged_in() {
        var e = Idle.effective(base(), false)
        compare(e.battery, false); compare(e.lock, 10); compare(e.off, 15); compare(e.suspend, 0); compare(e.dimAt, 570)
    }
    function test_on_battery() {
        var e = Idle.effective(base(), true)
        compare(e.battery, true); compare(e.lock, 5); compare(e.off, 10); compare(e.suspend, 15); compare(e.dimAt, 270)
    }
    function test_battery_set_off() {
        var s = base(); s.idleBatterySeparate = false
        var e = Idle.effective(s, true)
        compare(e.battery, false); compare(e.lock, 10); compare(e.suspend, 0)
    }
    function test_dim_before_first_action() {
        compare(Idle.dimAt(10, 5, 30), 270)
        compare(Idle.dimAt(0, 5, 30), 270)
        compare(Idle.dimAt(5, 0, 60), 240)
    }
    function test_dim_never_in_first_half() {
        compare(Idle.dimAt(1, 0, 60), 30)
        compare(Idle.dimAt(1, 2, 30), 30)
    }
    function test_dim_off() {
        compare(Idle.dimAt(10, 15, 0), 0)
        compare(Idle.dimAt(0, 0, 30), 0)
        compare(Idle.dimAt(10, 15, undefined), 0)
    }
    function test_labels() {
        compare(Idle.minLabel(0), "Never"); compare(Idle.minLabel(5), "5 min"); compare(Idle.minLabel(120), "2 h")
        compare(Idle.secLabel(0), "Off"); compare(Idle.secLabel(30), "30 s"); compare(Idle.secLabel(60), "1 min")
    }
}
