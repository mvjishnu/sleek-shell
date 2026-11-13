import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Session lock surface.  All visuals live in LockView; this file only maps the
// surface onto a monitor and keeps the lock UI at a fixed design scale so a
// monitor's desktop scale cannot change the clock size.
WlSessionLockSurface {
    id: surface
    required property var ctl
    color: "#10131d"

    readonly property bool primary: !!screen && (ctl.primaryScreen === "" || ctl.primaryScreen === screen.name)
    readonly property real monitorScale: {
        var monitor = screen ? Wm.monByName(screen.name) : null
        if (monitor && monitor.scale > 0) return monitor.scale
        return screen && screen.devicePixelRatio > 0 ? screen.devicePixelRatio : 1.25
    }
    readonly property real designWidth: width * monitorScale / 1.25
    readonly property real designHeight: height * monitorScale / 1.25
    readonly property real lockScale: 1.25 / monitorScale

    LockView {
        anchors.centerIn: parent
        width: surface.designWidth
        height: surface.designHeight
        scale: surface.lockScale
        ctl: surface.ctl
        primary: surface.primary
        surfaceScreen: surface.screen ? surface.screen.name : ""
    }
}
