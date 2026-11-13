import QtQuick

// Large, quiet digital time.  One text item, no decoration.
Item {
    id: root
    property date now: new Date()
    property bool is24h: false
    property color ink: "#f5f6f8"
    property string fontFamily: "sans-serif"

    readonly property string txt: pad(is24h ? now.getHours() : ((now.getHours() + 11) % 12 + 1)) + ":" + pad(now.getMinutes())
    function pad(n) { return (n < 10 ? "0" : "") + n }

    Text {
        anchors.centerIn: parent
        text: root.txt
        color: root.ink
        font.family: root.fontFamily
        font.weight: Font.Light
        font.pixelSize: Math.min(root.height * 1.08, root.width / (root.txt.length * 0.62))
    }
}
