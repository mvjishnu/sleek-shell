import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// Session and power actions. Lock and Suspend run immediately; Log out, Restart and Shut down
// need a second click within a few seconds (the row turns into its own confirmation).
ColumnLayout {
    id: pp
    property bool open: false
    Layout.fillWidth: true
    spacing: Theme.dropdownGap

    readonly property string user: Quickshell.env("USER") || ""
    property string host: ""
    property string uptime: ""
    property string armed: ""
    property int countdown: 0
    readonly property int confirmSecs: 4

    onOpenChanged: {
        armed = ""
        if (open && !info.running) info.running = true
    }
    Component.onCompleted: info.running = true

    Process {
        id: info
        command: ["sh", "-c", "cat /proc/sys/kernel/hostname; cut -d' ' -f1 /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n")
                pp.host = (l[0] || "").trim()
                var s = Math.floor(Number(l[1]) || 0), d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
                pp.uptime = s <= 0 ? "" : (d > 0 ? d + "d " + h + "h" : (h > 0 ? h + "h " + m + "m" : m + "m"))
            }
        }
    }

    Timer {
        id: tick
        interval: 1000; repeat: true
        running: pp.armed !== ""
        onTriggered: if (--pp.countdown <= 0) pp.armed = ""
    }

    function act(id, needsConfirm, fn) {
        if (needsConfirm && armed !== id) { armed = id; countdown = confirmSecs; tick.restart(); return }
        armed = ""
        Sys.close()
        fn()
    }

    Heading {
        title: "Power"
        subtitle: [pp.user + (pp.host !== "" ? "@" + pp.host : ""), pp.uptime !== "" ? "up " + pp.uptime : ""].filter(function (x) { return x !== "" }).join("  ·  ")
    }

    Repeater {
        model: [
            { id: "lock", code: Theme.ic.lock, accent: Theme.cyan, title: "Lock", hint: "SUPER + L", confirm: false },
            { id: "suspend", code: Theme.ic.suspend, accent: Theme.purple, title: "Suspend", hint: "", confirm: false },
            { id: "logout", code: Theme.ic.logout, accent: Theme.yellow, title: "Log out", hint: "", confirm: true },
            { id: "reboot", code: Theme.ic.restart, accent: Theme.pink, title: "Restart", hint: "", confirm: true },
            { id: "poweroff", code: Theme.ic.power, accent: Theme.red, title: "Shut down", hint: "", confirm: true }
        ]
        delegate: ColumnLayout {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: Theme.dropdownGap
            Divider { visible: index === 2 }
            ActionRow {
                readonly property bool isArmed: pp.armed === modelData.id
                code: modelData.code
                accent: modelData.accent
                highlighted: isArmed
                title: isArmed ? modelData.title + "?" : modelData.title
                subtitle: isArmed ? "Click again to confirm" : ""
                trailing: isArmed ? pp.countdown + "s" : modelData.hint
                Accessible.description: modelData.confirm ? "Asks for confirmation" : ""
                onClicked: pp.act(modelData.id, modelData.confirm, function () {
                    switch (modelData.id) {
                    case "lock": Sys.later(function () { Sys.lockRequested() }, 260); break
                    case "suspend": Sys.run(["systemctl", "suspend"]); break
                    case "logout": Sys.run(["hyprctl", "dispatch", "hl.dsp.exit()"]); break
                    case "reboot": Sys.run(["systemctl", "reboot"]); break
                    case "poweroff": Sys.run(["systemctl", "poweroff"]); break
                    }
                })
            }
        }
    }
}
