import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.services
import qs.components

ColumnLayout {
    Layout.fillWidth: true
    spacing: Theme.dropdownGap
    readonly property var sinks: Pipewire.nodes.values.filter(function (n) { return n.isSink && n.audio && !n.isStream })

    Heading { title: "Sound"; subtitle: !Sys.audioReady ? "PipeWire is not available" : (Sys.muted ? "Output muted" : Sys.sinkName) }
    SliderRow {
        code: Sys.muted || Sys.volume === 0 ? Theme.ic.volOff : Theme.ic.volHigh
        accent: Sys.muted ? Theme.muted : Theme.pink
        accessibleName: "Output volume"
        value: Sys.volume
        onMoved: v => Sys.setVolume(v)
        onIconClicked: Sys.toggleMute()
    }
    Divider {}
    ActionRow {
        code: Sys.micMuted ? Theme.ic.micOff : Theme.ic.mic
        accent: Sys.micMuted ? Theme.red : Theme.green
        title: "Microphone"
        subtitle: Sys.micMuted ? "Muted" : "Live"
        highlighted: Sys.micMuted
        onClicked: Sys.toggleMic()
        Toggle {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            checked: !Sys.micMuted; accent: Theme.green; accessibleName: "Microphone"
            onToggled: Sys.toggleMic()
        }
    }
    SectionLabel { visible: sinks.length > 1; title: "Output device" }
    Repeater {
        model: sinks.length > 1 ? sinks : []
        delegate: ActionRow {
            required property var modelData
            code: Theme.ic.volMed
            accent: modelData === Sys.sink ? Theme.pink : Theme.muted
            title: modelData.description || modelData.nickname || modelData.name
            highlighted: modelData === Sys.sink
            onClicked: Pipewire.preferredDefaultAudioSink = modelData
        }
    }
    MediaCard {}
    ActionRow { code: Theme.ic.cog; accent: Theme.muted; title: "Sound settings"; subtitle: "pavucontrol"; onClicked: { Sys.close(); Sys.run(["pavucontrol"]) } }
}
