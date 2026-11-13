import QtQuick

Item {
    id: digit
    property string value: "0"
    property color ink: "#dfe4f2"
    readonly property int cell: 7
    readonly property var shapes: ({
        "0":"111101101101111", "1":"010110010010111", "2":"111001111100111",
        "3":"111001111001111", "4":"101101111001001", "5":"111100111001111",
        "6":"111100111101111", "7":"111001001001001", "8":"111101111101111",
        "9":"111101111001111"
    })
    implicitWidth: cell * 3
    implicitHeight: cell * 5
    Repeater {
        model: 15
        delegate: Rectangle {
            required property int index
            readonly property string mask: digit.shapes[digit.value] || digit.shapes["0"]
            width: 2.4; height: width; radius: width / 2
            x: (index % 3) * digit.cell + 1.45
            y: Math.floor(index / 3) * digit.cell + 1.45
            color: digit.ink
            opacity: mask.charAt(index) === "1" ? 0.88 : 0.08
        }
    }
}
