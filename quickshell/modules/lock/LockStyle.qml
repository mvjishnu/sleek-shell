pragma Singleton
import QtQuick
import Quickshell
import qs.services

// =============================================================================
//  LockStyle — the lock screen's own settings.
//
//  The lock screen is deliberately kept away from Theme.qml:
//  moving the bar's frost slider, changing the palette or resizing the bar must
//  never change how the lock screen looks. Everything the lock screen needs to
//  look and feel right lives here, so it can be tuned on its own.
//
//  Colours still come from the palette, but LockScene copies them once, when
//  the lock engages. Edits made while the screen is locked are ignored until
//  the next lock.
// =============================================================================
Singleton {
    id: style

    // ---- frost -------------------------------------------------------------
    // The desktop is only ever shown as a wash: it is blurred down to a
    // quarter of its size (cheap, and it never has to re-blur while the
    // animation runs), then covered with a tint that leaves nothing readable.
    readonly property real frostScale: 4       // blur runs on a 1/4 size copy
    readonly property real blurRadius: 16      // in that small space (≈64 px full size)
    readonly property real saturation: 0.45    // drained, so no edge survives the blur
    readonly property real brightness: -0.04
    readonly property real washAlpha: 0.78     // tint that buries the blurred desktop
    readonly property real glassAlphaTop: 0.86 // the growing glass, top edge
    readonly property real glassAlphaBottom: 0.93

    // ---- lock-in animation (ms) --------------------------------------------
    // One continuous timeline: every move starts right after the previous one
    // has begun, so the lock never comes to a dead stop.
    readonly property int morphDur: 220    // bar clock pill -> round badge
    readonly property int dropDur: 360     // the lock falls out of the bar
    readonly property int spinDur: 400     // and spins down while it falls
    readonly property int latchDelay: 280  // it clicks shut as it lands
    readonly property int latchDur: 130
    readonly property int growDelay: 330   // the glass grows out of the badge
    readonly property int growDur: 330
    readonly property int contentDelay: 330 // the clock and password field arrive
    readonly property int contentDur: 240

    // ---- unlock animation (ms) ---------------------------------------------
    readonly property int outContentDur: 120
    readonly property int outLatchDelay: 60
    readonly property int outLatchDur: 130
    readonly property int outGrowDelay: 150
    readonly property int outGrowDur: 260
    readonly property int outDropDur: 300
    readonly property int outMorphDur: 200
    readonly property int outSpinDur: 300
    readonly property int releaseDelay: 520  // how long the surface stays up while unlocking

    // ---- colour helpers ----------------------------------------------------
    // tint = [r, g, b]; white mixes the tint toward white; alpha is the opacity.
    function tint(rgb, alpha, white) {
        return Qt.rgba((rgb[0] + (255 - rgb[0]) * white) / 255,
                       (rgb[1] + (255 - rgb[1]) * white) / 255,
                       (rgb[2] + (255 - rgb[2]) * white) / 255, alpha)
    }

    function lerp(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t,
                       a.a + (b.a - a.a) * t)
    }
}
