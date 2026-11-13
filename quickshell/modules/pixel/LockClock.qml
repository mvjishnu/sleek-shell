import QtQuick

// Selects one of the Nothing-inspired lock clocks.  Purely presentational:
// the owning surface supplies the current time, so the clock never animates
// between states — the hands/digits simply show the new value.
Item {
    id: root
    property date now: new Date()
    property bool is24h: false
    property string style: "digital"
    property string fontFamily: "sans-serif"
    property color ink: "#f5f6f8"
    property color accent: "#8fd7f5"

    Loader {
        anchors.fill: parent
        sourceComponent: root.style === "digital" ? digital
            : root.style === "flip" ? flip
            : root.style === "analog" ? analog
            : dots
    }

    Component {
        id: dots
        LockClockDots { now: root.now; is24h: root.is24h; ink: root.ink }
    }
    Component {
        id: digital
        LockClockDigital { now: root.now; is24h: root.is24h; ink: root.ink; fontFamily: root.fontFamily }
    }
    Component {
        id: flip
        LockClockFlip { now: root.now; is24h: root.is24h; ink: root.ink; fontFamily: root.fontFamily }
    }
    Component {
        id: analog
        LockClockAnalog { now: root.now; ink: root.ink; accent: root.accent }
    }
}
