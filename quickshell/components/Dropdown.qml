import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.services

// Dynamic-island dropdown: starts as a pill on top of its bar button, then springs open
// (width leads, height follows).
//
// Performance: the content column is laid out ONCE at its final width and stays put on screen;
// the card only reveals it (clip), so nothing re-lays-out per frame and no offscreen layer is
// re-allocated while the size animates. With animations off it opens instantly.
PopupWindow {
    id: win
    required property var barWindow
    property Item target: null
    required property string name
    property int panelWidth: 340
    default property alias content: col.data
    readonly property bool open: Sys.openPopup === name && Sys.openScreen === barWindow.screen.name

    readonly property real cardWidth: Math.min(panelWidth, Math.max(1, barWindow.width - Theme.popupEdgeInset * 2))
    readonly property real screenHeight: barWindow.screen ? barWindow.screen.height : barWindow.height
    readonly property real maxCardHeight: Math.max(startH, screenHeight - Theme.barHeight - Theme.popupEdgeInset * 2 - Theme.popupOverscan)
    readonly property real fullH: Math.min(col.implicitHeight + Theme.popupInset * 2, maxCardHeight)
    readonly property real finalX: Theme.popupOverscan

    property real originCx: 0
    property real startW: 40
    property real startH: 28
    property real pw: 0
    property real ph: 0

    anchor.window: barWindow
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY | PopupAdjustment.ResizeY
    implicitWidth: cardWidth + Theme.popupOverscan * 2
    implicitHeight: fullH + Theme.popupOverscan
    color: "transparent"
    grabFocus: true
    onVisibleChanged: if (!visible && open) dismissed()

    // the compositor ended the popup grab (outside click). A click on another bar button is swallowed
    // by the dismissal, so forward it: switching between bar panels stays a single click.
    function dismissed() {
        var hit = null
        var isl = barWindow.islands || {}
        for (var k in isl) if (!hit && isl[k] && isl[k] !== target) hit = hoveredButton(isl[k], 3)
        Sys.close()
        if (hit) { forward.hit = hit; forward.restart() }
    }
    function hoveredButton(it, depth) {
        if (!it || !it.visible) return null
        if (it.hovered === true && typeof it.clicked === "function") return it
        if (depth <= 0 || !it.children) return null
        for (var i = 0; i < it.children.length; i++) { var h = hoveredButton(it.children[i], depth - 1); if (h) return h }
        return null
    }
    // let the dismissed popup unmap first: Qt parents a new popup to the topmost grabbing one otherwise
    Timer { id: forward; interval: 60; property Item hit: null; onTriggered: { if (hit && Sys.openPopup === "") hit.clicked(); hit = null } }

    function refocus() { if (open && !keyScope.activeFocus) keyScope.forceActiveFocus() }

    function place() {
        // the widget may be hidden in Settings (e.g. opened by a shortcut): anchor near the right edge
        var p = target && target.visible ? target.mapToItem(null, 0, 0) : Qt.point(barWindow.width - 120, Theme.barMargin)
        var tw = target && target.visible ? target.width : 40, th = target && target.visible ? target.height : Theme.islandHeight
        var cx = p.x + tw / 2
        var wx = Math.max(Theme.popupEdgeInset, Math.min(cx - cardWidth / 2, barWindow.width - cardWidth - Theme.popupEdgeInset))
        anchor.rect.x = wx - Theme.popupOverscan
        anchor.rect.y = p.y
        anchor.rect.width = 1
        anchor.rect.height = th + 6
        originCx = cx - (wx - Theme.popupOverscan)
        startW = Math.min(tw + 4, cardWidth)
        startH = Math.min(th, fullH)
    }

    onOpenChanged: {
        if (open) {
            place()
            scroll.contentY = 0
            closeAnim.stop()
            if (!visible) { pw = 0; ph = 0 }
            visible = true
            keyScope.forceActiveFocus()
            if (Theme.animations) { wOpen.restart(); hOpen.restart() }
            else { pw = 1; ph = 1 }
        } else {
            wOpen.stop(); hOpen.stop()
            if (Theme.animations) closeAnim.restart()
            else { pw = 0; ph = 0; visible = false }
        }
    }

    SpringAnimation { id: wOpen; target: win; property: "pw"; to: 1; spring: 7.0 * Math.sqrt(Theme.animSpeed); damping: 0.32; epsilon: 0.002 }
    SpringAnimation { id: hOpen; target: win; property: "ph"; to: 1; spring: 5.5 * Math.sqrt(Theme.animSpeed); damping: 0.30; epsilon: 0.002 }
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: win; property: "pw"; to: 0; duration: Theme.dur(140); easing.type: Easing.InCubic }
        NumberAnimation { target: win; property: "ph"; to: 0; duration: Theme.dur(140); easing.type: Easing.InCubic }
        onFinished: if (!win.open) win.visible = false
    }

    HyprlandFocusGrab {
        windows: [win, win.barWindow]
        active: win.open && !win.grabFocus
        onCleared: if (win.open) Sys.close()
    }

    Rectangle {   // soft drop shadow (Theme.shadows)
        visible: Theme.shadows
        x: card.x + 1; y: card.y + 4
        width: card.width; height: card.height
        radius: card.radius
        color: Theme.shadowColor
        opacity: card.opacity
    }

    Rectangle {
        id: card
        clip: true
        y: 0
        width: win.startW + (win.cardWidth - win.startW) * win.pw
        height: win.startH + (win.fullH - win.startH) * win.ph
        x: win.originCx + (win.finalX + win.cardWidth / 2 - win.originCx) * win.pw - width / 2
        radius: Math.min(height / 2, Theme.radius)
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.glassPopTop }
            GradientStop { position: 1; color: Theme.glassPopBottom }
        }
        border.width: Theme.strokeWidth
        border.color: Theme.stroke
        opacity: Math.min(1, win.pw * 5)

        Flickable {
            id: scroll
            // fixed final geometry, expressed in card coordinates: content never moves or re-flows
            x: win.finalX - card.x + Theme.popupInset
            y: Theme.popupInset
            width: win.cardWidth - Theme.popupInset * 2
            height: Math.max(0, win.fullH - Theme.popupInset * 2)
            contentWidth: width
            contentHeight: col.implicitHeight
            clip: contentHeight > height
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            opacity: Math.max(0, Math.min(1, (win.ph - 0.4) / 0.45))

            FocusScope {
                id: keyScope
                width: scroll.width
                height: col.implicitHeight
                focus: true
                Keys.onEscapePressed: e => { Sys.close(); e.accepted = true }
                Window.onActiveFocusItemChanged: if (win.open && !keyScope.activeFocus) Qt.callLater(win.refocus)
                ColumnLayout {
                    id: col
                    width: scroll.width
                    spacing: Theme.dropdownGap
                }
            }
        }

        Rectangle {
            visible: scroll.contentHeight > scroll.height && scroll.height > 0
            width: 3
            height: Math.max(20, scroll.height * scroll.height / scroll.contentHeight)
            radius: 2
            color: Qt.alpha(Theme.accent, 0.72)
            x: card.width - width - 5
            y: Theme.popupInset + (scroll.contentHeight > scroll.height
                ? (scroll.height - height) * scroll.contentY / (scroll.contentHeight - scroll.height) : 0)
        }
    }
}
