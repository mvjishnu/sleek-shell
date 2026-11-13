import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Radial network/device picker. Nodes sit in rings around the central radio hub;
// tapping a node activates it, and dropping it on the hub performs the same action.
Item {
    id: orbit
    property var entries: []
    property string mimeType: "application/x-sleek-orbit"
    property string hubTitle: "Wi-Fi"
    property string hubSubtitle: "On"
    property color accent: Theme.cyan
    property bool dragging: false
    readonly property int maxNodes: 10
    readonly property var orbitEntries: entries.slice(0, maxNodes)
    readonly property real hubX: width / 2
    readonly property real hubY: height / 2
    property real rotationAngle: 0

    Layout.fillWidth: true
    implicitHeight: 300

    // Slow continuous orbit. A timer (not a frame-driven NumberAnimation) keeps the
    // layout cheap: the nodes re-position a few dozen times a second instead of on
    // every compositor frame, and the motion pauses while you drag a node or when
    // animations are turned off. One revolution takes about 100 seconds.
    property real rotationSpeed: 0.12   // degrees per tick
    Timer {
        interval: 33
        repeat: true
        running: Theme.animations && !orbit.dragging && orbit.orbitEntries.length > 0
        onTriggered: orbit.rotationAngle = (orbit.rotationAngle + orbit.rotationSpeed) % 360
    }

    function activateKey(key, dropped) {
        for (var i = 0; i < orbit.orbitEntries.length; ++i) {
            if (String(orbit.orbitEntries[i].key) === String(key)) {
                orbit.activated(orbit.orbitEntries[i], dropped)
                return
            }
        }
    }
    signal activated(var entry, bool dropped)
    signal toggleRequested()

    Repeater {
        model: orbit.orbitEntries.length > 6 ? 2 : (orbit.orbitEntries.length > 0 ? 1 : 0)
        delegate: Rectangle {
            required property int index
            readonly property real diameter: index === 0
                ? (orbit.orbitEntries.length > 6 ? 204 : 224) : 260
            width: diameter; height: diameter; radius: diameter / 2
            x: orbit.hubX - width / 2; y: orbit.hubY - height / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(orbit.accent, index === 0 ? 0.28 : 0.22)
            antialiasing: true
        }
    }

    Repeater {
        model: orbit.orbitEntries
        delegate: Rectangle {
            id: node
            required property var modelData
            required property int index
            readonly property bool twoRings: orbit.orbitEntries.length > 6
            readonly property bool innerRing: twoRings && index < 4
            readonly property int ringCount: !twoRings ? orbit.orbitEntries.length
                : (innerRing ? 4 : orbit.orbitEntries.length - 4)
            readonly property int ringIndex: !twoRings ? index : (innerRing ? index : index - 4)
            readonly property real orbitRadius: !twoRings ? 112 : (innerRing ? 102 : 128)
            readonly property real angle: (ringIndex / Math.max(1, ringCount)) * Math.PI * 2
                + orbit.rotationAngle * Math.PI / 180 - Math.PI / 2
            readonly property var dragPayload: {
                var payload = {}
                payload[orbit.mimeType] = String(modelData.key)
                return payload
            }
            property bool dragImageReady: false
            x: orbit.hubX + Math.cos(angle) * orbitRadius - width / 2
                + (dragHandler.active ? dragHandler.activeTranslation.x : 0)
            y: orbit.hubY + Math.sin(angle) * orbitRadius - height / 2
                + (dragHandler.active ? dragHandler.activeTranslation.y : 0)
            width: 104
            height: 48
            radius: 16
            antialiasing: true
            opacity: dragHandler.active && dragImageReady ? 0 : 1
            color: modelData.active ? Qt.alpha(orbit.accent, 0.26) : Theme.glassPopBottom
            border.width: modelData.active ? 1.5 : 1
            border.color: modelData.active ? Qt.alpha(orbit.accent, 0.8) : Theme.pillStroke
            z: dragHandler.active ? 10 : 2
            Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }

            DragHandler {
                id: dragHandler
                target: null
                onActiveChanged: {
                    orbit.dragging = active
                    node.dragImageReady = false
                    if (active) {
                        node.grabToImage(function(result) {
                            if (dragHandler.active) {
                                node.Drag.imageSource = result.url
                                node.dragImageReady = true
                            }
                        })
                    }
                }
            }
            Drag.dragType: Drag.Automatic
            Drag.active: dragHandler.active && node.dragImageReady
            Drag.hotSpot: Qt.point(width / 2, height / 2)
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: node.dragPayload

            Column {
                anchors.centerIn: parent
                width: parent.width - 14
                spacing: 1
                Text {
                    width: parent.width
                    text: node.modelData.title
                    color: Theme.text
                    font.family: Theme.font; font.pixelSize: 11; font.weight: node.modelData.active ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    width: parent.width
                    text: node.modelData.subtitle
                    color: node.modelData.active ? orbit.accent : Theme.muted
                    font.family: Theme.font; font.pixelSize: 9
                    elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                }
            }
            TapHandler { onTapped: orbit.activated(node.modelData, false) }
            Accessible.role: Accessible.Button
            Accessible.name: node.modelData.title + ", " + node.modelData.subtitle
        }
    }

    Rectangle {
        id: hub
        width: 88; height: 88; radius: 44
        x: orbit.hubX - width / 2; y: orbit.hubY - height / 2
        color: hubDrop.containsDrag ? Qt.alpha(orbit.accent, 0.36) : Theme.glassPopTop
        border.width: hubDrop.containsDrag ? 2 : 1.5
        border.color: hubDrop.containsDrag ? orbit.accent : Qt.alpha(orbit.accent, 0.58)
        antialiasing: true
        z: 5
        Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
        Behavior on border.color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
        Column {
            anchors.centerIn: parent
            spacing: 1
            Glyph { anchors.horizontalCenter: parent.horizontalCenter; code: hubDrop.containsDrag ? Theme.ic.drop : (orbit.hubTitle === "Bluetooth" ? Theme.ic.bt : Theme.ic.wifi); color: orbit.accent; size: 18 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; width: 76; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; text: hubDrop.containsDrag ? "Drop here" : orbit.hubTitle; color: Theme.text; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold }
            Text { anchors.horizontalCenter: parent.horizontalCenter; width: 76; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; text: hubDrop.containsDrag ? "to connect" : orbit.hubSubtitle; color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
        }
        TapHandler { onTapped: orbit.toggleRequested() }
        DropArea {
            id: hubDrop
            anchors.fill: parent
            keys: [orbit.mimeType]
            onDropped: drop => orbit.activateKey(drop.getDataAsString(orbit.mimeType), true)
        }
        Accessible.role: Accessible.Button
        Accessible.name: orbit.hubTitle + " " + orbit.hubSubtitle + ". Drop a nearby device here."
    }
}
