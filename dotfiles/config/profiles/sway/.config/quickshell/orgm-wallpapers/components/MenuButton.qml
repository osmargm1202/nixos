import QtQuick
import qs.config

Rectangle {
    id: root
    property string text: ""
    property bool highlighted: false
    signal clicked()
    implicitWidth: 160
    implicitHeight: 48
    radius: Style.radiusSmall
    color: highlighted ? Style.accent : Style.surface
    border.width: activeFocus ? 2 : 0
    border.color: Style.accent
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Text {
        anchors { fill: parent; margins: 8 }
        text: root.text
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        color: root.highlighted ? Style.bg : Style.fg
        font.family: Style.font
        font.pixelSize: Style.fontNormal
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
