import QtQuick
import QtQuick.Layouts
import qs.services

// Full-width row with icon, text, optional trailing text. Used for lists and power actions.
Rectangle {
    id: r
    property int code: 0
    property color accent: Theme.cyan
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property bool highlighted: false
    property bool enabled: true
    property var dragData: ({})
    property bool dragConsumed: false
    signal clicked()
    opacity: enabled ? 1 : 0.5
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: title
    Keys.onPressed: e => { if (r.enabled && (e.key === Qt.Key_Return || e.key === Qt.Key_Space)) { r.clicked(); e.accepted = true } }

    DragHandler {
        id: rowDrag
        target: null
        enabled: Object.keys(r.dragData).length > 0
        onActiveChanged: if (active) r.dragConsumed = true
    }
    Drag.active: rowDrag.active
    Drag.supportedActions: Qt.CopyAction
    Drag.mimeData: r.dragData
    Timer { interval: 120; running: r.dragConsumed; onTriggered: r.dragConsumed = false }

    Layout.fillWidth: true
    implicitHeight: subtitle !== "" ? 50 : 42
    radius: Math.max(16, Theme.controlRadius + 4)
    antialiasing: true
    color: highlighted ? Qt.alpha(accent, 0.16) : (ma.containsMouse || activeFocus ? Theme.surface : "transparent")
    Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
        spacing: 10
        Glyph { code: r.code; color: r.accent }
        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Text {
                text: r.title; color: Theme.text
                font.family: Theme.font; font.pixelSize: Theme.fontLg; font.weight: r.highlighted ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight; Layout.fillWidth: true
            }
            Text {
                visible: r.subtitle !== ""
                text: r.subtitle; color: Theme.muted
                font.family: Theme.font; font.pixelSize: Theme.fontSm
                elide: Text.ElideRight; Layout.fillWidth: true
            }
        }
        Text {
            visible: r.trailing !== ""
            text: r.trailing; color: Theme.muted
            font.family: Theme.font; font.pixelSize: Theme.fontMd
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: r.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { if (!r.dragConsumed) r.clicked(); r.dragConsumed = false }
    }
}
