import QtQuick

// Minimal dotted dial: twelve hour dots, two hands and a thin accent second hand.
Item {
    id: root
    property date now: new Date()
    property color ink: "#f5f6f8"
    property color accent: "#8fd7f5"

    readonly property real diameter: Math.min(root.height * 0.98, root.width * 0.5)

    Item {
        id: dial
        width: root.diameter
        height: root.diameter
        anchors.centerIn: parent

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(root.ink, 0.22)
        }

        Repeater {
            model: 12
            delegate: Rectangle {
                required property int index
                width: dial.width * 0.028; height: width; radius: width / 2
                color: Qt.alpha(root.ink, 0.82)
                x: dial.width / 2 + Math.sin(index * Math.PI / 6) * (dial.width / 2 - dial.width * 0.06) - width / 2
                y: dial.height / 2 - Math.cos(index * Math.PI / 6) * (dial.height / 2 - dial.height * 0.06) - height / 2
            }
        }

        Item {
            width: dial.width * 0.022
            height: dial.height * 0.24
            x: dial.width / 2 - width / 2
            y: dial.height / 2 - height
            transformOrigin: Item.Bottom
            rotation: ((root.now.getHours() % 12) + root.now.getMinutes() / 60) * 30
            Rectangle { anchors.fill: parent; radius: width / 2; color: root.ink }
        }
        Item {
            width: dial.width * 0.015
            height: dial.height * 0.34
            x: dial.width / 2 - width / 2
            y: dial.height / 2 - height
            transformOrigin: Item.Bottom
            rotation: root.now.getMinutes() * 6
            Rectangle { anchors.fill: parent; radius: width / 2; color: root.ink }
        }
        Rectangle {
            width: dial.width * 0.04; height: width; radius: width / 2
            anchors.centerIn: parent
            color: root.accent
        }
    }
}
