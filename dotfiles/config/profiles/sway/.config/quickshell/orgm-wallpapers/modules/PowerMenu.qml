import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs.components

// Adapted from shadowofdominance/swaydots, pinned in ../NOTICE.md.
MenuWindow {
    id: root
    layerNamespace: "orgm-power"
    property var catalog: ({})
    readonly property var actions: [
        { icon: "\uf023", label: "Bloquear" },
        { icon: "\uf186", label: "Suspender" },
        { icon: "\uf08b", label: "Cerrar sesión" },
        { icon: "\uf021", label: "Reiniciar" },
        { icon: "\uf011", label: "Apagar" }
    ]
    property int selected: 0
    property bool confirming: false
    readonly property string choice: actions[selected].label
    readonly property real buttonSize: Math.min(128, (width - 64 - row.spacing * 4) / 5)
    signal chosen(string value)
    screen: Quickshell.screens.find(s => s.name === root.catalog.screen) || Quickshell.screens[0]
    onSelectedChanged: confirming = false

    function move(delta) { selected = Math.max(0, Math.min(actions.length - 1, selected + delta)) }
    function activate() {
        if (!open) return
        if (selected >= 2 && !confirming) { confirming = true; return }
        chosen(choice)
    }
    onKeyPressed: event => {
        switch (event.key) {
        case Qt.Key_Left: case Qt.Key_H: move(-1); break
        case Qt.Key_Right: case Qt.Key_L: move(1); break
        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: if (!event.isAutoRepeat) activate(); break
        case Qt.Key_1: case Qt.Key_2: case Qt.Key_3: case Qt.Key_4: case Qt.Key_5:
            selected = event.key - Qt.Key_1; break
        }
        event.accepted = true
    }
    Row {
        id: row
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - root.progress) * 30 - 28
        spacing: Math.min(22, root.width * 0.02)
        opacity: root.progress
        Repeater {
            model: root.actions
            delegate: Rectangle {
                id: button
                required property int index
                required property var modelData
                readonly property bool active: root.selected === index
                width: root.buttonSize
                height: width
                radius: width * 0.235
                color: active ? Style.accent : Style.panel
                border.width: 1
                border.color: active ? "transparent" : Style.outline
                scale: active ? 1.06 : 1
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.35
                    shadowBlur: 0.9
                    shadowVerticalOffset: 8
                }
                Text {
                    anchors.centerIn: parent
                    text: button.modelData.icon
                    font.family: Style.font
                    font.pixelSize: root.buttonSize * 0.36
                    color: button.active ? Style.bg : Style.fg
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selected = button.index
                    onClicked: { root.selected = button.index; root.activate() }
                }
            }
        }
    }
    Surface {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: row.bottom
        anchors.topMargin: 34
        width: label.implicitWidth + 36
        height: 44
        opacity: root.progress
        Text {
            id: label
            anchors.centerIn: parent
            text: root.confirming ? "¿" + root.choice + "?" : root.choice
            color: Style.fg
            font.family: Style.font
            font.pixelSize: Style.fontLarge
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: row.bottom
        anchors.topMargin: 98
        opacity: root.progress
        text: root.confirming ? "Enter o clic de nuevo para confirmar · Esc: cancelar"
                              : "← →: elegir · Enter: aceptar · Esc o clic fuera: cerrar"
        color: Style.muted
        font.family: Style.font
        font.pixelSize: Style.fontSmall
    }
}
