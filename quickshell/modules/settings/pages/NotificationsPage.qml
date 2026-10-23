import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components
import qs.modules.settings

SettingsPage {
    title: "Notifications"
    subtitle: "Sleek Shell is the only notification server; history is kept for the session."

    SettingsSection {
        SettingRow { title: "Do not disturb"; subtitle: "Silence pop-ups. Critical notifications still appear. Right-click the bell to toggle."
            Toggle { checked: Settings.dnd; accent: Theme.pink; accessibleName: "Do not disturb"; onToggled: Sys.setDnd(!Settings.dnd) } }
        LabeledSlider {
            label: "Pop-up duration"; valueText: Settings.toastTimeout + " s"
            code: Theme.ic.bell; accent: Theme.yellow
            from: 0; value: (Settings.toastTimeout - 2) / 28 * 100
            onMoved: v => Settings.set("toastTimeout", 2 + v / 100 * 28)
            onReset: Settings.set("toastTimeout", 6)
        }
        LabeledSlider {
            label: "Pop-ups shown at once"; valueText: Settings.toastMax
            code: Theme.ic.bellRing; accent: Theme.yellow
            from: 0; value: (Settings.toastMax - 1) / 5 * 100
            onMoved: v => Settings.set("toastMax", 1 + v / 100 * 5)
            onReset: Settings.set("toastMax", 3)
        }
        LabeledSlider {
            label: "History size"; valueText: Settings.historyMax + " notifications"
            code: Theme.ic.clipboard; accent: Theme.cyan
            from: 0; value: (Settings.historyMax - 10) / 290 * 100
            onMoved: v => Settings.set("historyMax", 10 + v / 100 * 290)
            onReset: Settings.set("historyMax", 80)
        }
        RowLayout {
            spacing: 8
            UiBtn { label: "Send a test notification"; code: Theme.ic.bell; onClicked: Sys.run(["notify-send", "-a", "Sleek Shell", "-A", "ok=Looks good", "Test notification", "Pop-ups, actions and history are working."]) }
            UiBtn { label: "Clear history"; code: Theme.ic.trash; enabled: Notifs.history.length > 0; onClicked: Notifs.clear() }
        }
    }
}
