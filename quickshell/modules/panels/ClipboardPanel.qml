import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

ColumnLayout {
    id: clip
    property bool open: false
    property string query: ""
    Layout.fillWidth: true
    spacing: Theme.dropdownGap
    onOpenChanged: if (open) { query = ""; search.text = ""; search.focusField() }

    Heading {
        title: "Clipboard"
        subtitle: Sys.clipboard.length ? Sys.clipboard.length + " entries · click to copy" : "Click an entry to copy it"
        IconButton { code: Theme.ic.refresh; tooltip: "Refresh"; onClicked: Sys.loadClipboard() }
        IconButton { code: Theme.ic.trash; tooltip: "Clear history"; enabled: Sys.clipboard.length > 0; onClicked: Sys.wipeClip() }
    }
    UiField {
        id: search
        Layout.fillWidth: true
        implicitHeight: 38
        code: Theme.ic.search
        placeholder: "Search clipboard history"
        onEdited: clip.query = text.toLowerCase()
        onAccepted: if (cList.count > 0) Sys.copyClip(cList.model[0].id)
    }
    ListView {
        id: cList
        visible: count > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 380)
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: Sys.clipboard.filter(function (e) { return clip.query === "" || e.text.toLowerCase().indexOf(clip.query) >= 0 }).slice(0, 60)
        delegate: ActionRow {
            required property var modelData
            width: cList.width
            code: modelData.isImage ? Theme.ic.image : Theme.ic.copy
            accent: modelData.isImage ? Theme.pink : Theme.cyan
            title: modelData.isImage ? "Image" : modelData.text
            subtitle: modelData.isImage ? modelData.text.replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "") : ""
            onClicked: Sys.copyClip(modelData.id)
        }
    }
    Empty {
        visible: cList.count === 0
        code: Theme.ic.clipboard
        title: clip.query === "" ? "Clipboard is empty" : "No matches"
        hint: clip.query === "" ? "Copy something and it will show up here" : "Try a different search"
    }
}
