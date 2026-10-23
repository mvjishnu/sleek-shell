import QtQuick
import Quickshell.Widgets
import qs.services

// The user's profile picture (~/.config/sleek-shell/avatar, set in Settings › Lock screen), clipped to a
// circle. Falls back to a gradient with the initial when there is no picture or it cannot be read.
ClippingRectangle {
    id: av
    property int size: 72
    property string name: ""
    property bool showPicture: true
    property color tone: Theme.accentBase
    readonly property bool hasPicture: pic.status === Image.Ready
    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    antialiasing: true
    color: "transparent"
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#8be0ff" }
            GradientStop { position: 1; color: av.tone }
        }
    }
    Text {
        anchors.centerIn: parent
        visible: !av.hasPicture
        text: (av.name || "?").charAt(0).toUpperCase()
        color: "#ffffff"
        font.family: Theme.font
        font.pixelSize: Math.round(av.size * 0.42)
        font.weight: Font.Bold
    }
    Image {
        id: pic
        anchors.fill: parent
        visible: status === Image.Ready
        // the stamp makes a new URL whenever the picture is replaced, so the image cache cannot serve the old one
        source: av.showPicture && Settings.hasAvatar ? "file://" + Settings.avatarPath + "#" + Settings.avatarStamp : ""
        sourceSize: Qt.size(av.size * 2, av.size * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
    }
}
