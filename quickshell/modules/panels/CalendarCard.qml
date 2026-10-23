import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Clock face + month grid. Bind `now` to SystemClock.date and `active` to the dropdown's open state.
ColumnLayout {
    id: cal
    property date now: new Date()
    property bool active: false
    property int year: new Date().getFullYear()
    property int month: new Date().getMonth()
    property var cells: []
    spacing: 10
    Layout.fillWidth: true

    function build() {
        var first = new Date(year, month, 1)
        var offset = (first.getDay() + 6) % 7
        var start = new Date(year, month, 1 - offset)
        var t = new Date()
        var out = []
        for (var i = 0; i < 42; ++i) {
            var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month,
                today: d.getDate() === t.getDate() && d.getMonth() === t.getMonth() && d.getFullYear() === t.getFullYear()
            })
        }
        cells = out
    }
    function shift(delta) {
        var d = new Date(year, month + delta, 1)
        year = d.getFullYear(); month = d.getMonth(); build()
    }
    function reset() {
        var t = new Date()
        year = t.getFullYear(); month = t.getMonth(); build()
    }
    onActiveChanged: if (active) reset()
    Component.onCompleted: build()
    onNowChanged: clock.requestPaint()

    // Clock header
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        Canvas {
            id: clock
            Layout.preferredWidth: 104
            Layout.preferredHeight: 104
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2, cy = height / 2, r = width / 2 - 4
                ctx.fillStyle = "#1affffff"
                ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill()
                ctx.strokeStyle = "#2effffff"; ctx.lineWidth = 1
                ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()
                for (var i = 0; i < 12; i++) {
                    var a = i * Math.PI / 6
                    var major = i % 3 === 0
                    var r1 = r - (major ? 10 : 6), r2 = r - 3
                    ctx.strokeStyle = major ? "#8be0ff" : "#6f6c97"
                    ctx.lineWidth = major ? 2 : 1
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.sin(a) * r1, cy - Math.cos(a) * r1)
                    ctx.lineTo(cx + Math.sin(a) * r2, cy - Math.cos(a) * r2)
                    ctx.stroke()
                }
                var n = cal.now
                var sec = n.getSeconds(), min = n.getMinutes() + sec / 60, hr = (n.getHours() % 12) + min / 60
                function hand(angle, len, w, col) {
                    ctx.strokeStyle = col; ctx.lineWidth = w; ctx.lineCap = "round"
                    ctx.beginPath(); ctx.moveTo(cx, cy)
                    ctx.lineTo(cx + Math.sin(angle) * len, cy - Math.cos(angle) * len)
                    ctx.stroke()
                }
                hand(hr / 12 * Math.PI * 2, r * 0.5, 4, "#b69aff")
                hand(min / 60 * Math.PI * 2, r * 0.75, 3, "#f4f1ff")
                hand(sec / 60 * Math.PI * 2, r * 0.82, 1.5, "#ff70c5")
                ctx.fillStyle = "#ff70c5"
                ctx.beginPath(); ctx.arc(cx, cy, 3.5, 0, Math.PI * 2); ctx.fill()
            }
        }
        ColumnLayout {
            spacing: 2
            Layout.fillWidth: true
            Text {
                text: Qt.formatDateTime(cal.now, Settings.clock24h ? "HH:mm" : "h:mm AP").replace(/ (AM|PM)$/, "")
                color: Theme.text
                font.family: Theme.font; font.pixelSize: 34; font.weight: Font.Bold
            }
            Text {
                text: Qt.formatDateTime(cal.now, Settings.clock24h ? "ss" : "ss AP").replace(/^/, ":")
                color: Theme.cyan
                font.family: Theme.font; font.pixelSize: 13
            }
            Text {
                text: Qt.formatDateTime(cal.now, "dddd, d MMMM")
                color: Theme.muted
                font.family: Theme.font; font.pixelSize: 13
            }
        }
    }

    Divider {}

    // Month nav
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: new Date(cal.year, cal.month, 1).toLocaleDateString(Qt.locale(), "MMMM yyyy")
            color: Theme.text
            font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
            Layout.fillWidth: true
        }
        IconButton { code: Theme.ic.left; onClicked: cal.shift(-1) }
        IconButton {
            code: Theme.ic.check
            color: Theme.cyan
            onClicked: cal.reset()
        }
        IconButton { code: Theme.ic.right; onClicked: cal.shift(1) }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 2
        columnSpacing: 2
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            delegate: Text {
                required property string modelData
                Layout.fillWidth: true
                text: modelData
                color: Theme.dim
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.font; font.pixelSize: 11
            }
        }
        Repeater {
            model: cal.cells
            delegate: Item {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                Rectangle {
                    anchors.centerIn: parent
                    width: 30; height: 30; radius: 15
                    visible: modelData.today || dayMa.containsMouse
                    color: modelData.today ? "transparent" : Theme.surface
                    gradient: modelData.today ? todayGrad : null
                }
                Gradient {
                    id: todayGrad
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.cyan }
                    GradientStop { position: 1; color: Theme.purple }
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData.day
                    color: modelData.today ? Theme.onAccent : (modelData.inMonth ? Theme.text : Theme.dim)
                    font.family: Theme.font; font.pixelSize: 12
                    font.weight: modelData.today ? Font.Bold : Font.Normal
                }
                MouseArea { id: dayMa; anchors.fill: parent; hoverEnabled: true }
            }
        }
    }
}
