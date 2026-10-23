import QtQuick
import QtQuick.Layouts
import qs.services

// Live conflict check under a shortcut field.
Text {
    required property var page
    property string keys: ""
    property string selfId: ""
    readonly property var hits: keys.trim() === "" ? [] : page.conflictsFor(keys, selfId)
    visible: hits.length > 0
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    text: hits.length ? "Already used by “" + hits[0].label + "”" + (hits[0].kind === "builtin" ? " (" + hits[0].category + "). Disable or move that one first." : ".") : ""
    color: Theme.red
    font.family: Theme.font; font.pixelSize: Theme.fontSm
}
