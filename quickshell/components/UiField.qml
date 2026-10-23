import QtQuick
import qs.services

// Single-line text field.
Rectangle {
    id: f
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property int code: 0
    property bool error: false
    signal accepted()
    signal edited()
    function focusField() { input.forceActiveFocus() }
    implicitHeight: 32; implicitWidth: 200
    radius: Theme.smallRadius
    antialiasing: true
    color: input.activeFocus ? Theme.surfaceHi : Theme.surface
    border.width: input.activeFocus || f.error ? 2 : Theme.strokeWidth
    border.color: f.error ? Theme.red : (input.activeFocus ? Theme.accent : Theme.stroke)
    Behavior on color { enabled: Theme.animations; ColorAnimation { duration: Theme.durFast } }
    Glyph { id: lead; visible: f.code > 0; code: f.code; size: 14; color: Theme.muted; implicitWidth: 18; implicitHeight: 18
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter } }
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: f.code > 0 ? 30 : 10; rightMargin: 10 }
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text; selectionColor: Theme.accent; selectedTextColor: Theme.onAccent
        font.family: Theme.font; font.pixelSize: Theme.fontMd
        clip: true
        activeFocusOnTab: true
        onAccepted: f.accepted()
        onTextEdited: f.edited()
    }
    Text {
        anchors { fill: input }
        verticalAlignment: Text.AlignVCenter
        visible: input.text === "" && !input.activeFocus
        text: f.placeholder; color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontMd
        elide: Text.ElideRight
    }
}
