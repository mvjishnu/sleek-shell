import QtQuick

// Split-card clock: hours and minutes on two solid cards with a dot separator.
Item {
    id: root
    property date now: new Date()
    property bool is24h: false
    property color ink: "#f5f6f8"
    property string fontFamily: "sans-serif"

    readonly property string hh: pad(is24h ? now.getHours() : ((now.getHours() + 11) % 12 + 1))
    readonly property string mm: pad(now.getMinutes())
    function pad(n) { return (n < 10 ? "0" : "") + n }

    readonly property real cardH: Math.min(root.height * 0.88, root.width * 0.3)
    readonly property real cardW: cardH * 0.8

    component Card: Rectangle {
        id: card
        property string value
        width: root.cardW
        height: root.cardH
        radius: height * 0.12
        color: Qt.alpha("#0d1017", 0.62)
        border.width: 1
        border.color: Qt.alpha("#ffffff", 0.12)
        Text {
            anchors.centerIn: parent
            text: card.value
            color: root.ink
            font.family: root.fontFamily
            font.pixelSize: card.height * 0.6
            font.weight: Font.Bold
        }
        Rectangle {   // split-flap seam
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: 1
            color: Qt.alpha("#000000", 0.28)
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: root.cardH * 0.1
        Card { value: root.hh }
        Column {
            width: root.cardW * 0.22
            height: root.cardH
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.cardH * 0.14
            Repeater {
                model: 2
                delegate: Rectangle {
                    width: root.cardH * 0.1; height: width; radius: width / 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Qt.alpha(root.ink, 0.7)
                }
            }
        }
        Card { value: root.mm }
    }
}
