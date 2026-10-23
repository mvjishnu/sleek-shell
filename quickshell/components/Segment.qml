import QtQuick
import QtQuick.Layouts
import qs.services

// Pill segmented control: one option is active at a time.
//
// model:   [{ id: "dark", label: "Dark", code: 1234 }, ...]
// current: id of the active option
Item {
    id: seg
    property var model: []
    property string current: ""
    signal picked(string optionId)

    implicitHeight: 32
    Layout.fillWidth: true

    readonly property int count: (model && model.length > 0) ? model.length : 1
    readonly property int currentIndex: {
        if (!model) return -1
        for (var i = 0; i < model.length; ++i)
            if (model[i].id === current) return i
        return -1
    }

    Rectangle {                       // track
        anchors.fill: parent
        radius: height / 2
        antialiasing: true
        color: Theme.surface
        border.width: Theme.strokeWidth
        border.color: Theme.stroke
    }

    Rectangle {                       // knob on the active option
        id: knob
        y: 2
        height: parent.height - 4
        width: (parent.width - 4) / seg.count
        x: 2 + width * Math.max(0, seg.currentIndex)
        radius: height / 2
        antialiasing: true
        visible: seg.currentIndex >= 0
        color: Theme.accent
        Behavior on x { enabled: Theme.animations; NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Repeater {
            model: seg.model
            delegate: Item {
                id: opt
                required property var modelData
                readonly property bool active: seg.current === modelData.id
                Layout.fillWidth: true
                Layout.fillHeight: true
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.label
                Accessible.checked: active
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        seg.picked(modelData.id)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                        seg.picked(seg.model[Math.max(0, seg.currentIndex - 1)].id)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                        seg.picked(seg.model[Math.min(seg.count - 1, seg.currentIndex + 1)].id)
                        event.accepted = true
                    }
                }

                Rectangle {
                    anchors { fill: parent; margins: 2 }
                    radius: height / 2
                    color: "transparent"
                    border.width: opt.activeFocus ? 2 : 0
                    border.color: Theme.text
                }
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 7
                    Glyph {
                        code: opt.modelData.code || 0
                        color: opt.active ? Theme.onAccent : Theme.muted
                        size: 15
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: opt.modelData.label
                        color: opt.active ? Theme.onAccent : Theme.muted
                        font.family: Theme.font; font.pixelSize: 12
                        font.weight: opt.active ? Font.DemiBold : Font.Normal
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { opt.forceActiveFocus(); seg.picked(opt.modelData.id) }
                }
            }
        }
    }
}
