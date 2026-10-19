import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.I3
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config

PanelWindow {
    id: root
    property bool active: false
    property real progress: active ? 1 : 0
    property string target: "output"
    property string outputName: ""
    property var node: null
    property real percent: 0
    property bool muted: false
    readonly property string state: muted ? "muted" : percent >= 150 ? "maximum" : percent > 100 ? "boosted" : percent <= 0 ? "zero" : "normal"
    readonly property color accent: muted ? Style.muted : percent > 100 ? Style.error : Style.accent
    readonly property string stateText: muted ? "Silenciado" : percent >= 150 ? "Máximo" : percent > 100 ? "Amplificado" : percent <= 0 ? "Sin volumen" : ""
    screen: Quickshell.screens.find(s => s.name === outputName) || Quickshell.screens[0]
    visible: active || progress > 0
    color: "transparent"
    implicitWidth: Math.min(400, screen ? screen.width - 40 : 400)
    implicitHeight: 134
    anchors.bottom: true
    margins.bottom: screen ? Math.max(40, Math.round(screen.height * 0.1)) : 80
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "orgm-audio-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    function present(audioNode, value, isMuted, kind) {
        target = kind || (audioNode && !audioNode.isSink ? "input" : "output")
        node = audioNode
        percent = Math.max(0, Math.min(150, value))
        muted = isMuted
        outputName = Style.hyprlandSession
            ? (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
            : (I3.focusedMonitor ? I3.focusedMonitor.name : "")
        active = true
        if (!slider.pressed && !muteButton.pressed) hideTimer.restart()
    }
    function snapshot() {
        return { active, visible, target, percent: Math.round(percent), muted, state,
            devicePercent: node && node.audio ? Math.round(node.audio.volume * 100) : null,
            screen: screen ? screen.name : "", layer: "overlay", keyboardFocus: "none",
            width, height, bottom: margins.bottom, accent: String(accent),
            slider: { x: slider.x, y: slider.y, width: slider.width, height: slider.height,
                leftPadding: slider.leftPadding, availableWidth: slider.availableWidth } }
    }
    Behavior on progress { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Timer {
        id: hideTimer
        interval: root.muted || root.percent >= 150 ? 2000 : 1400
        onTriggered: root.active = false
    }
    Rectangle {
        anchors { fill: parent; topMargin: (1 - root.progress) * 12 }
        radius: 22
        color: Style.panel
        border.width: 1
        border.color: Style.outline
        opacity: root.progress
        Row {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 22 }
            spacing: 16
            Button {
                id: muteButton
                width: 38; height: 44
                focusPolicy: Qt.NoFocus
                enabled: !!(root.node && root.node.audio)
                text: root.target === "input" ? (root.muted ? "󰍭" : "󰍬") : (root.muted ? "󰝟" : "󰕾")
                background: Rectangle { radius: 10; color: parent.hovered ? Style.surface : "transparent" }
                contentItem: Text { text: parent.text; color: root.accent; font.family: Style.font; font.pixelSize: 31; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: AudioModel.mute(root.node)
                onPressedChanged: { if (pressed) hideTimer.stop(); else if (root.active) hideTimer.restart() }
            }
            Column {
                width: parent.width - 38 - 72 - parent.spacing * 2
                spacing: 5
                Text { text: root.target === "input" ? "Micrófono" : "Volumen"; color: Style.fg; font.family: Style.font; font.pixelSize: 17 }
                Text {
                    width: parent.width
                    text: root.node ? (root.node.description || root.node.name) : ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Style.muted; font.family: Style.font; font.pixelSize: 11
                }
            }
            Text { width: 72; text: Math.round(root.percent) + "%"; color: root.accent; font.family: Style.font; font.pixelSize: 24; horizontalAlignment: Text.AlignRight }
        }
        Slider {
            id: slider
            x: 22; y: 74
            width: parent.width - 44; height: 26
            from: 0; to: 150; stepSize: 1
            value: root.percent
            enabled: !!(root.node && root.node.audio)
            focusPolicy: Qt.NoFocus
            onMoved: AudioModel.volume(root.node, value)
            onPressedChanged: { if (pressed) hideTimer.stop(); else if (root.active) hideTimer.restart() }
            background: Rectangle {
                x: slider.leftPadding; y: (slider.height - height) / 2
                width: slider.availableWidth; height: 7; radius: 4
                color: Style.surface
                Rectangle {
                    width: slider.visualPosition * parent.width; height: parent.height; radius: 4; color: root.accent
                    Behavior on width { enabled: !slider.pressed; NumberAnimation { duration: 80 } }
                }
                Rectangle { x: parent.width * 2 / 3; y: -2; width: 2; height: 11; radius: 1; color: Style.muted }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: (slider.height - height) / 2
                width: 15; height: 15; radius: 8; color: root.accent
                Behavior on x { enabled: !slider.pressed; NumberAnimation { duration: 80 } }
            }
        }
        Text { x: 22; y: 108; text: root.stateText; color: root.accent; font.family: Style.font; font.pixelSize: 11 }
        Text { x: slider.x + slider.leftPadding + slider.availableWidth * 2 / 3 - width / 2; y: 108; text: "100%"; color: Style.muted; font.family: Style.font; font.pixelSize: 10 }
    }
}
