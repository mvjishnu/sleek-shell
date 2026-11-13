import QtQuick
import qs.services

// Compact centered workspace overview. One card strip per connected monitor.
Item {
    id: strips
    required property var controller
    required property Item keyScope
    required property Item dragGhost

    Column {
        id: monitorRows
        anchors.centerIn: parent
        spacing: 12
        Repeater {
            model: strips.controller.model
            delegate: Column {
                id: section
                required property var modelData
                required property int index
                readonly property int count: modelData.ws.length
                readonly property int tileW: Math.max(120, Math.min(200, Math.floor((strips.width - 120 - count * 12) / count)))
                readonly property int tileH: 152
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: section.modelData.name + (section.modelData.focused ? "  ·  focused" : "")
                    color: Theme.text
                    font.family: Theme.font; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold
                }

                Rectangle {
                    id: group
                    width: cardRow.implicitWidth + 24
                    height: cardRow.implicitHeight + 24
                    radius: Theme.radius
                    color: Theme.surface
                    border.width: Theme.strokeWidth
                    border.color: section.modelData.focused ? Qt.alpha(Theme.accent, 0.6) : Theme.border

                    Row {
                        id: cardRow
                        anchors.centerIn: parent
                        spacing: 8
                        Repeater {
                            model: section.modelData.ws
                            delegate: Rectangle {
                                id: card
                                required property var modelData
                                required property int index
                                readonly property string key: section.modelData.name + "|" + modelData.id
                                readonly property bool selected: modelData.active || (strips.controller.selMon === section.index && strips.controller.selIdx === index)
                                readonly property bool dropTarget: strips.controller.dragging && strips.controller.hoverKey === key
                                width: section.tileW; height: section.tileH; radius: Theme.controlRadius; clip: true
                                color: Theme.surfaceHi
                                border.width: card.dropTarget ? Math.max(3, Theme.strokeWidth + 2)
                                    : (card.selected ? Math.max(2, Theme.strokeWidth + 1) : Theme.strokeWidth)
                                border.color: card.dropTarget || card.selected ? Theme.accent : Qt.alpha(Theme.text, 0.36)
                                Component.onCompleted: strips.controller.cards[key] = card
                                Component.onDestruction: delete strips.controller.cards[key]

                                TapHandler {
                                    onTapped: card.modelData.id === "new"
                                        ? strips.controller.newWs(section.modelData.name)
                                        : strips.controller.activateWs(card.modelData.id)
                                }

                                Item {
                                    id: preview
                                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 8; rightMargin: 8; topMargin: 8; bottomMargin: 8 }
                                    readonly property real fit: Math.min(width / Math.max(1, section.modelData.lw), height / Math.max(1, section.modelData.lh))
                                    readonly property real contentW: section.modelData.lw * fit
                                    readonly property real contentH: section.modelData.lh * fit
                                    readonly property real offX: (width - contentW) / 2
                                    readonly property real offY: (height - contentH) / 2
                                    Rectangle { anchors.fill: parent; radius: Theme.smallRadius; color: Qt.alpha(Theme.text, 0.035); border.width: 1; border.color: Qt.alpha(Theme.text, 0.14) }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: card.modelData.extra
                                        text: "+"
                                        color: Theme.muted
                                        font.family: Theme.font
                                        font.pixelSize: 28
                                        font.weight: Font.Light
                                    }
                                    Repeater {
                                        model: card.modelData.wins
                                        delegate: Rectangle {
                                            id: app
                                            required property var modelData
                                            required property int index
                                            property bool dragged: false
                                            readonly property real rawX: preview.offX + (app.modelData.at[0] - section.modelData.mx) * preview.fit
                                            readonly property real rawY: preview.offY + (app.modelData.at[1] - section.modelData.my) * preview.fit
                                            x: Math.max(preview.offX, Math.min(preview.offX + preview.contentW - width, rawX))
                                            y: Math.max(preview.offY, Math.min(preview.offY + preview.contentH - height, rawY))
                                            width: Math.max(12, Math.min(preview.contentW, app.modelData.size[0] * preview.fit))
                                            height: Math.max(10, Math.min(preview.contentH, app.modelData.size[1] * preview.fit))
                                            radius: Math.max(2, Math.round(4 * Theme.radiusScale))
                                            clip: true
                                            color: app.modelData.focused ? Qt.alpha(Theme.accent, 0.72)
                                                : Qt.alpha(Theme.accent, app.modelData.floating ? 0.38 : 0.24)
                                            border.width: app.modelData.focused || strips.controller.dragging && strips.controller.dragWin.address === app.modelData.address ? 2 : 1
                                            border.color: app.modelData.focused || strips.controller.dragging && strips.controller.dragWin.address === app.modelData.address ? Theme.text : Qt.alpha(Theme.accent, 0.8)
                                            Image {
                                                anchors { left: parent.left; top: parent.top; margins: 2 }
                                                width: Math.min(14, parent.width - 4); height: Math.min(14, parent.height - 4)
                                                source: app.modelData.icon; sourceSize: Qt.size(28, 28); asynchronous: true; cache: true
                                            }
                                            Text {
                                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 3 }
                                                visible: parent.width > 45 && parent.height > 24
                                                text: app.modelData.title
                                                color: Theme.text; font.family: Theme.font; font.pixelSize: 8
                                                elide: Text.ElideRight
                                            }
                                            TapHandler {
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                onPressedChanged: if (pressed) app.dragged = false
                                                onTapped: (point, button) => {
                                                    if (button === Qt.RightButton) strips.controller.moveMenuWin = app.modelData
                                                    else if (!app.dragged) { Wm.focusWindow(app.modelData.address); strips.controller.hide() }
                                                }
                                            }
                                            DragHandler {
                                                id: appDrag
                                                parent: app
                                                target: null
                                                acceptedButtons: Qt.LeftButton
                                                property point dropPosition: Qt.point(0, 0)
                                                function updatePointer() {
                                                    var p = app.mapToItem(strips.keyScope, centroid.position.x, centroid.position.y)
                                                    dropPosition = p
                                                    strips.dragGhost.x = p.x + 8
                                                    strips.dragGhost.y = p.y + 8
                                                    strips.controller.hoverKey = strips.controller.cardAt(p.x, p.y)
                                                }
                                                onActiveChanged: {
                                                    if (active) {
                                                        app.dragged = true
                                                        strips.controller.dragWin = app.modelData
                                                        strips.controller.dragging = true
                                                        updatePointer()
                                                    } else if (app.dragged && strips.controller.dragging) {
                                                        strips.controller.dropOn(strips.controller.cardAt(dropPosition.x, dropPosition.y))
                                                    }
                                                }
                                                onCentroidChanged: if (active) updatePointer()
                                            }
                                        }
                                    }
                                }

                            }
                        }

                    }
                }
            }
        }
    }
}
