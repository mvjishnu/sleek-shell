import QtQuick
import qs.services

// Two-click destructive/expensive action: first click arms, second click confirms.
UiBtn {
    id: cb
    property string baseLabel: "Install"
    property string confirmLabel: "Confirm"
    property bool armed: false
    label: cb.armed ? cb.confirmLabel : cb.baseLabel
    selected: cb.armed
    signal confirmed()
    onClicked: {
        if (cb.armed) { cb.armed = false; cb.confirmed() }
        else { cb.armed = true; disarm.restart() }
    }
    Timer { id: disarm; interval: 4000; onTriggered: cb.armed = false }
}
