import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components
import qs.modules.lock

// One lock screen per monitor.
//
// This is only a host: the look and the motion live in LockScene.qml and the
// settings in LockStyle.qml, so the lock screen can be changed on its own
// without touching the bar.
//
// Timeline: the bar's clock pill lets go, turns into a round badge and a padlock
// drops out of the bar spinning, lands in the middle and latches shut, then the
// glass grows out of it to fill the screen.
// Unlocking plays the same thing backwards: shackle pops open, glass shrinks,
// the lock flies back up into the bar.
WlSessionLockSurface {
    id: surf
    required property var ctl
    color: "#08070f"   // opaque, so the desktop can never leak through

    LockScene {
        id: lockScene
        anchors.fill: parent
        ctl: surf.ctl
        // screen is only known once the compositor hands us the surface
        shotPath: surf.screen ? "file:///tmp/qs-lock-" + surf.screen.name + ".png" : ""
        // the card goes on the focused monitor; the others show the clock
        primary: !!surf.screen && (Wm.focusedMon() === "" || Wm.focusedMon() === surf.screen.name)
    }

    // The scene starts its animation when the surface shows up.
    Connections {
        target: surf
        function onVisibleChanged() { if (surf.visible) lockScene.startIntro() }
    }
}
