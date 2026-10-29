import QtQuick

FocusScope {
    id: clock
    signal dismissed()
    property date now: new Date()
    property bool twelveHour: false
    focus: true
    Keys.onPressed: event => { event.accepted = true; clock.dismissed() }
    Timer { interval: 1000; running: clock.visible; repeat: true; onTriggered: clock.now = new Date() }
    Rectangle { anchors.fill: parent; color: "#000000" }
    Row {
        anchors.centerIn: parent
        spacing: Math.max(10, Math.min(clock.width, clock.height) * 0.025)
        Repeater {
            model: [clock.twelveHour ? String(clock.now.getHours() % 12 || 12).padStart(2, "0") : Qt.formatDateTime(clock.now, "HH"), Qt.formatDateTime(clock.now, "mm")]
            Rectangle {
                required property string modelData
                onModelDataChanged: flip.restart()
                width: Math.min(clock.width * 0.32, clock.height * 0.50)
                height: width * 1.12
                radius: width * 0.045
                color: "#1c1c1c"
                border.color: "#303030"; border.width: 1
                Rectangle { anchors.left: parent.left; anchors.right: parent.right; height: parent.height / 2; radius: parent.radius; color: "#222222" }
                Text {
                    id: digits
                    anchors.centerIn: parent
                    text: parent.modelData
                    color: "#f2f1ed"; font.family: "DejaVu Sans"; font.bold: true
                    font.pixelSize: parent.width * 0.70
                }
                SequentialAnimation {
                    id: flip
                    NumberAnimation { target: digits; property: "scale"; to: 0.94; duration: 120 }
                    NumberAnimation { target: digits; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
                }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 2; color: "#080808"; opacity: 0.8 }
                Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 5; height: 12; color: "#060606"; radius: 2 }
                Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 5; height: 12; color: "#060606"; radius: 2 }
            }
        }
    }
    MouseArea {
        anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons
        onPressed: clock.dismissed()
        onWheel: event => { event.accepted = true; clock.dismissed() }
        onPositionChanged: mouse => { if (mouse.buttons !== Qt.NoButton) clock.dismissed() }
    }
}
