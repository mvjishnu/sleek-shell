pragma Singleton
import QtQuick
import Quickshell

// One clock for the whole shell. Minute precision unless something visible needs seconds
// (the calendar's analog clock, or "show seconds" in Settings), so the bar is not
// re-evaluated every second while idle.
Singleton {
    id: time
    readonly property bool needSeconds: Settings.clockSeconds || Sys.openPopup === "calendar"
    SystemClock { id: clock; precision: time.needSeconds ? SystemClock.Seconds : SystemClock.Minutes }
    readonly property date date: (clock && clock.date) ? clock.date : new Date()
    function fmtTime(d) { return Qt.formatDateTime(d, (Settings.clock24h ? "HH:mm" : "hh:mm") + (Settings.clockSeconds ? ":ss" : "") + (Settings.clock24h ? "" : " AP")) }
    function fmtDate(d) { return Qt.formatDateTime(d, "ddd, MMM d") }
}
