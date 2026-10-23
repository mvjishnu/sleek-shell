import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components
import qs.modules.settings

SettingsPage {
    id: lp
    title: "Launcher & calculator"
    subtitle: "Rofi app launcher and the Sleek Shell calculator / unit converter. Colours, font and icon theme follow Appearance."
    readonly property string home: Quickshell.env("HOME")
    readonly property string calcPy: home + "/.local/share/sleek-shell/calc/sleek_calc.py"
    property var rofi: ({})
    property string rofiMsg: ""
    property int historyCount: -1

    Process {
        id: rofiGet
        running: true
        command: ["python3", Quickshell.shellPath("scripts/rofi-prefs.py"), "get"]
        stdout: StdioCollector { onStreamFinished: lp.takeRofi(text) }
    }
    Process {
        id: rofiSet
        stdout: StdioCollector { onStreamFinished: lp.takeRofi(text) }
    }
    function takeRofi(t) {
        try { var o = JSON.parse(t); if (o.ok) { rofi = o; rofiMsg = "" } else rofiMsg = o.error || "Could not read the Rofi config" }
        catch (e) { rofiMsg = "Could not read ~/.config/rofi/config.rasi" }
    }
    function setRofi(k, v) {
        if (rofiSet.running) return
        var o = Object.assign({}, rofi); o[k] = v; rofi = o
        rofiSet.command = ["python3", Quickshell.shellPath("scripts/rofi-prefs.py"), "set", k, v ? "true" : "false"]
        rofiSet.running = true
    }

    Process {
        id: histCount
        running: true
        command: ["python3", lp.calcPy, "--history-count"]
        stdout: StdioCollector { onStreamFinished: lp.historyCount = parseInt(text) }
    }
    Process {
        id: histClear
        command: ["python3", lp.calcPy, "--clear-history"]
        onExited: histCount.running = true
    }
    Component.onCompleted: Settings.refreshCalc()

    SettingsSection {
        title: "Shortcuts"
        SettingRow {
            title: "App launcher"
            subtitle: "Search and open apps"
            RowLayout { spacing: 8; KeyCaps { keys: "SUPER" } UiBtn { label: "Open"; code: Theme.ic.apps; onClicked: { Ui.closeSettings(); Quickshell.execDetached(["sh", "-c", "sleep 0.3; rofi -show drun"]) } } }
        }
        SettingRow {
            title: "Calculator & unit converter"
            subtitle: "Type an expression, e.g. sin(30)+2^8 or 10 miles to km. Enter copies the result."
            RowLayout { spacing: 8; KeyCaps { keys: "SUPER + ALT + C" } UiBtn { label: "Open"; code: Theme.ic.search; onClicked: { Ui.closeSettings(); Quickshell.execDetached(["sh", "-c", "sleep 0.3; exec ~/.local/bin/sleek-calc"]) } } }
        }
        SettingRow {
            title: "Change shortcuts"
            subtitle: "Every key binding is editable in Keyboard"
            UiBtn { label: "Keyboard"; code: Theme.ic.keyboard; onClicked: Ui.settingsPage = "keyboard" }
        }
    }

    SettingsSection {
        title: "Launcher behaviour"
        subtitle: "Saved in ~/.config/rofi/config.rasi. Takes effect the next time Rofi opens."
        SettingRow {
            title: "Show app icons"
            subtitle: "Icon theme: Settings › Appearance"
            Toggle { checked: lp.rofi["show-icons"] === true; accessibleName: "Show app icons"; onToggled: lp.setRofi("show-icons", !checked) }
        }
        SettingRow {
            title: "Select on hover"
            subtitle: "Moving the pointer over a result highlights it"
            Toggle { checked: lp.rofi["hover-select"] === true; accessibleName: "Select on hover"; onToggled: lp.setRofi("hover-select", !checked) }
        }
        SettingRow {
            title: "Sort by match quality"
            subtitle: "Off keeps Rofi's own order (most used apps first)"
            Toggle { checked: lp.rofi.sort === true; accessibleName: "Sort by match quality"; onToggled: lp.setRofi("sort", !checked) }
        }
        SettingRow {
            title: "Case-sensitive search"
            Toggle { checked: lp.rofi["case-sensitive"] === true; accessibleName: "Case-sensitive search"; onToggled: lp.setRofi("case-sensitive", !checked) }
        }
        Text {
            visible: lp.rofiMsg !== ""
            Layout.fillWidth: true
            text: lp.rofiMsg
            color: Theme.red
            font.family: Theme.font; font.pixelSize: Theme.fontMd
        }
    }

    SettingsSection {
        title: "Calculator"
        subtitle: "Works offline. Saved in ~/.config/sleek-shell/settings.json and used the next time the calculator opens."
        SectionLabel { title: "Angle unit"; subtitle: "Used by sin, cos, tan and their inverses. You can also type \"deg\" or \"rad\" in the calculator." }
        Segment {
            model: [{ id: "deg", label: "Degrees", code: 0 }, { id: "rad", label: "Radians", code: 0 }]
            current: Settings.calc.angleMode
            onPicked: optionId => Settings.setCalc("angleMode", optionId)
        }
        SectionLabel { title: "Precision"; subtitle: "Significant digits in results (" + Settings.calc.precision + "). Higher values show more digits for long decimals." }
        Segment {
            model: [6, 8, 10, 12, 16, 24, 32].map(function (n) { return { id: String(n), label: String(n), code: 0 } })
            current: String(Settings.calc.precision)
            onPicked: optionId => Settings.setCalc("precision", Number(optionId))
        }
        Divider {}
        SettingRow {
            title: "History"
            subtitle: lp.historyCount < 0 ? "…" : (lp.historyCount === 0 ? "No saved results" : lp.historyCount + " saved result" + (lp.historyCount === 1 ? "" : "s") + " (last 50 are kept, shown when the calculator opens)")
            UiBtn { label: "Clear history"; code: Theme.ic.trash; danger: true; enabled: lp.historyCount > 0 && !histClear.running; onClicked: histClear.running = true }
        }
    }
}
