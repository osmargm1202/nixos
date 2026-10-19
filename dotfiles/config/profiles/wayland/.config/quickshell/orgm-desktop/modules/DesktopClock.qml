// Adapted from Ryoku desktop clock; see ../NOTICE.md and COPYING.
import QtQuick
import qs.config

Column {
    spacing: 14 * Settings.clockScale
    ClockDigital { anchors.horizontalCenter: parent.horizontalCenter }
    DateInline {
        visible: Settings.values.dateShow !== false
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
