import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Clock and calendar side by side. Bind `now` to SystemClock.date and `active` to the dropdown's open state.
RowLayout {
    id: cal
    property date now: new Date()
    property bool active: false
    property int year: new Date().getFullYear()
    property int month: new Date().getMonth()
    property var cells: []
    spacing: 18
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
    function dayOfYear(d) {
        return Math.floor((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(d.getFullYear(), 0, 0)) / 86400000)
    }
    function weekOfYear(d) {
        var utc = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        var day = utc.getUTCDay() || 7
        utc.setUTCDate(utc.getUTCDate() + 4 - day)
        var start = new Date(Date.UTC(utc.getUTCFullYear(), 0, 1))
        return Math.ceil((((utc - start) / 86400000) + 1) / 7)
    }
    onActiveChanged: if (active) reset()
    Component.onCompleted: build()
    onNowChanged: clock.requestPaint()

    // Rectangular analog clock above the digital time in the left column.
    ColumnLayout {
        Layout.preferredWidth: 320
        Layout.alignment: Qt.AlignVCenter
        spacing: 8
        Canvas {
            id: clock
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 288
            Layout.preferredHeight: 144
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2, cy = height / 2
                for (var i = 0; i < 12; i++) {
                    var a = i * Math.PI / 6
                    var major = i % 3 === 0
                    ctx.strokeStyle = major ? "#8be0ff" : "#6f6c97"
                    ctx.lineWidth = major ? 2 : 1
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.sin(a) * width * 0.39, cy - Math.cos(a) * height * 0.32)
                    ctx.lineTo(cx + Math.sin(a) * width * 0.44, cy - Math.cos(a) * height * 0.40)
                    ctx.stroke()
                }
                var n = cal.now
                var sec = n.getSeconds(), min = n.getMinutes() + sec / 60, hr = (n.getHours() % 12) + min / 60
                function hand(angle, len, w, col) {
                    ctx.strokeStyle = col; ctx.lineWidth = w; ctx.lineCap = "round"
                    ctx.beginPath(); ctx.moveTo(cx, cy)
                    ctx.lineTo(cx + Math.sin(angle) * width * 0.38 * len, cy - Math.cos(angle) * height * 0.34 * len)
                    ctx.stroke()
                }
                hand(hr / 12 * Math.PI * 2, 0.5, 4, "#b69aff")
                hand(min / 60 * Math.PI * 2, 0.78, 3, "#f4f1ff")
                hand(sec / 60 * Math.PI * 2, 0.9, 1.5, "#ff70c5")
                ctx.fillStyle = "#ff70c5"
                ctx.beginPath(); ctx.arc(cx, cy, 3.5, 0, Math.PI * 2); ctx.fill()
            }
        }
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2
            Text {
                id: mainTime
                text: Qt.formatDateTime(cal.now, Settings.clock24h ? "HH:mm" : "h:mm")
                color: Theme.text
                font.family: Theme.font; font.pixelSize: 34; font.weight: Font.Bold
            }
            Text {
                text: ":" + Qt.formatDateTime(cal.now, "ss")
                color: Theme.text
                anchors.baseline: mainTime.baseline
                font.family: Theme.font; font.pixelSize: 34; font.weight: Font.Bold
            }
            Text {
                visible: !Settings.clock24h
                text: Qt.formatDateTime(cal.now, "AP")
                color: Theme.text
                anchors.baseline: mainTime.baseline
                font.family: Theme.font; font.pixelSize: 34; font.weight: Font.Bold
            }
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2
            Text {
                text: Qt.formatDateTime(cal.now, "dddd, d MMM yyyy")
                color: Theme.muted
                font.family: Theme.font; font.pixelSize: 13
            }
            Text {
                text: "Week " + cal.weekOfYear(cal.now) + "  ·  Day " + cal.dayOfYear(cal.now)
                color: Theme.dim
                font.family: Theme.font; font.pixelSize: 11
            }
        }
    }

    Rectangle {
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        color: Theme.stroke
    }

    // Month navigation and date grid occupy the right column.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 380
        spacing: 8
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
                    Layout.preferredHeight: 36
                    Rectangle {
                        anchors.centerIn: parent
                        width: 32; height: 32; radius: 16
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
                        font.family: Theme.font; font.pixelSize: 13
                        font.weight: modelData.today ? Font.Bold : Font.Normal
                    }
                    MouseArea { id: dayMa; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }
    }
}
