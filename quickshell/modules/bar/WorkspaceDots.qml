import QtQuick
import Quickshell.Hyprland
import qs.services
import qs.components

// Per-monitor workspace indicator: only this monitor's workspaces, in allocator order.
// Click to switch, scroll to step (monitor scoped); the active one stretches into a gradient capsule.
Item {
    id: wd
    required property string screenName
    readonly property bool numbers: Settings.workspaceStyle === "numbers"
    readonly property int dot: Math.round(Theme.islandHeight * 0.27)              // 7 px compact
    readonly property int chip: Math.round(Theme.islandHeight * 0.66)             // numbers mode
    implicitHeight: Theme.islandHeight
    implicitWidth: row.width + (numbers ? 8 : 22)

    readonly property var mine: {
        var v = Hyprland.workspaces.values, out = []
        for (var i = 0; i < v.length; ++i) if (v[i].id > 0 && (!v[i].monitor || v[i].monitor.name === screenName)) out.push(v[i])
        var order = Wm.wsIds(screenName)
        out.sort(function (a, b) { var ia = order.indexOf(a.id), ib = order.indexOf(b.id); return (ia < 0 ? 1e6 + a.id : ia) - (ib < 0 ? 1e6 + b.id : ib) })
        return out
    }

    Row {
        id: row
        anchors.centerIn: parent
        height: parent.height
        spacing: wd.numbers ? 3 : 6
        Repeater {
            model: wd.mine
            delegate: Item {
                id: cell
                required property var modelData
                readonly property bool isActive: modelData.active
                readonly property bool urgent: modelData.urgent
                height: row.height
                width: wd.numbers ? Math.max(wd.chip, num.implicitWidth + 10) : (isActive ? wd.dot * 3 : wd.dot)
                Behavior on width { enabled: Theme.animations; NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: wd.numbers ? wd.chip : wd.dot
                    radius: height / 2
                    antialiasing: true
                    color: cell.urgent ? Theme.pink : (cell.isActive ? "transparent" : (wd.numbers ? (wsMa.containsMouse ? Theme.pillPress : Theme.pillHover) : (wsMa.containsMouse ? Theme.muted : Theme.dim)))
                    gradient: cell.isActive && !cell.urgent ? activeGrad : null
                    Gradient {
                        id: activeGrad
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.barTone(Theme.cyan) }
                        GradientStop { position: 1; color: Theme.accent }
                    }
                    scale: wsMa.containsMouse && !cell.isActive && !wd.numbers ? 1.3 : 1
                    Behavior on scale { enabled: Theme.animations; NumberAnimation { duration: Theme.durFast } }
                    Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
                }
                BarLabel {
                    id: num
                    visible: wd.numbers
                    x: Math.round((cell.width - implicitWidth) / 2)
                    height: cell.height
                    size: Theme.barLabelSize - 1
                    text: (Wm.wsIds(wd.screenName).indexOf(cell.modelData.id) + 1) || cell.modelData.name
                    color: cell.isActive ? Theme.onAccent : Theme.muted
                }
                MouseArea {
                    id: wsMa
                    anchors { fill: parent; leftMargin: -3; rightMargin: -3 }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wm.gotoWs(cell.modelData.id)
                }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => Wm.stepWs(wd.screenName, wheel.angleDelta.y > 0 ? -1 : 1)
    }
}
