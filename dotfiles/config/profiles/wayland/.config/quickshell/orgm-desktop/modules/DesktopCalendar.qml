// Adapted from Ryoku CalendarWidget/CalendarGrid; see ../NOTICE.md and COPYING.
import QtQuick
import qs.config
import "../lib/calendar.js" as Model

Rectangle {
    id: root
    readonly property var loc: Settings.formatLoc
    readonly property date today: Settings.now
    property int year: today.getFullYear()
    property int month: today.getMonth()
    property string selected: Model.dateKey(today.getFullYear(), today.getMonth(), today.getDate())
    readonly property int firstDay: loc.firstDayOfWeek % 7
    readonly property var days: Model.buildRange(today, year, month, Settings.values.calendarWeeks || 6, firstDay)
    readonly property real s: Settings.values.calendarScale || 1
    readonly property string monthLabel: loc.standaloneMonthName(month, Locale.LongFormat) + " " + year
    implicitWidth: grid.implicitWidth + 40 * s
    implicitHeight: grid.implicitHeight + 84 * s
    radius: 20 * s
    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, .9)
    function shift(delta) {
        const next = delta === 0 ? { year: today.getFullYear(), month: today.getMonth() } : Model.shiftMonth(year, month, delta)
        year = next.year
        month = next.month
    }
    Text {
        x: 20 * root.s; y: 18 * root.s
        text: root.monthLabel
        font.family: Theme.font
        font.pixelSize: 16 * root.s
        font.weight: Font.DemiBold
        color: Theme.ink
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 12 * root.s
        y: 10 * root.s
        Repeater {
            model: ["‹", "Hoy", "›"]
            delegate: Rectangle {
                required property int index
                required property string modelData
                width: (index === 1 ? 42 : 30) * root.s
                height: 32 * root.s
                radius: 8 * root.s
                color: mouse.containsMouse ? Theme.tileHover : "transparent"
                Accessible.role: Accessible.Button
                Accessible.name: ["Mes anterior", "Mes actual", "Mes siguiente"][index]
                Text { anchors.centerIn: parent; text: modelData; color: Theme.ink; font.pixelSize: 14 * root.s }
                MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.shift(index - 1) }
            }
        }
    }
    CalendarGrid {
        id: grid
        x: 20 * root.s; y: 52 * root.s
        days: root.days
        weeks: root.days.length / 7
        firstDay: root.firstDay
        loc: root.loc
        showWeekNumbers: Settings.values.calendarWeekNumbers !== false
        selectedKey: root.selected
        s: root.s
        onSelected: key => root.selected = key
    }
}
