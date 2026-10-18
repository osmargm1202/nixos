import QtQuick
import QtQuick.Controls
import qs.config

Column {
    id: root
    property string label: ""
    property real level: 0
    property real maximum: 100
    property real minimum: 0
    signal adjusted(real percent)
    spacing: 6
    height: 66
    Text {
        text: root.label + " · " + Math.round(slider.value) + "%"
        color: root.enabled ? Style.fg : Style.muted
        font.family: Style.font
        font.pixelSize: Style.fontNormal
    }
    Slider {
        id: slider
        width: parent.width
        height: 30
        from: root.minimum
        to: root.maximum
        stepSize: 1
        value: root.level
        onMoved: root.adjusted(value)
        background: Rectangle {
            x: slider.leftPadding
            y: (slider.height - height) / 2
            width: slider.availableWidth
            height: 6
            radius: 3
            color: Style.surface
            Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 3; color: Style.accent }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: (slider.height - height) / 2
            width: 18; height: 18; radius: 9
            color: Style.accent
            border.width: slider.activeFocus ? 2 : 0
            border.color: Style.fg
        }
    }
}
