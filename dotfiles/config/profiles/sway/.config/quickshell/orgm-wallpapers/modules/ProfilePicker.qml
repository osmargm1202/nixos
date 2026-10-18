import QtQuick
import Quickshell
import qs.config
import qs.components

// Local profile cards, using the upstream menus' shared visual primitives.
MenuWindow {
    id: root
    layerNamespace: "orgm-profiles"
    property var catalog: ({})
    readonly property var profiles: catalog.items || []
    property int selected: 0
    readonly property bool confirming: false
    readonly property string choice: profiles[selected] ? profiles[selected].id : ""
    readonly property real cardWidth: Math.min(330, (width - 80) / 3 - 20)
    signal chosen(string value)
    screen: Quickshell.screens.find(s => s.name === root.catalog.screen) || Quickshell.screens[0]
    onCatalogChanged: selected = Math.max(0, (catalog.items || []).findIndex(p => p.id === catalog.current))
    function move(delta) { selected = Math.max(0, Math.min(profiles.length - 1, selected + delta)) }
    function activate() { if (open && choice) chosen(choice) }
    onKeyPressed: event => {
        switch (event.key) {
        case Qt.Key_Left: case Qt.Key_H: move(-1); break
        case Qt.Key_Right: case Qt.Key_L: move(1); break
        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: if (!event.isAutoRepeat) activate(); break
        case Qt.Key_1: case Qt.Key_2: case Qt.Key_3: selected = Math.min(profiles.length - 1, event.key - Qt.Key_1); break
        }
        event.accepted = true
    }
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - root.progress) * 30
        spacing: 28
        opacity: root.progress
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Perfil visual"
            color: Style.fg
            font.family: Style.font
            font.pixelSize: 26
        }
        Row {
            spacing: 20
            Repeater {
                model: root.profiles
                delegate: Rectangle {
                    id: card
                    required property int index
                    required property var modelData
                    readonly property bool active: root.selected === index
                    width: root.cardWidth
                    height: width * 0.65 + 68
                    color: Style.panel
                    radius: Style.radius
                    border.width: active ? 2 : 1
                    border.color: active ? Style.accent : Style.outline
                    scale: active ? 1.025 : 1
                    Behavior on scale { NumberAnimation { duration: Style.animMed; easing.type: Easing.OutCubic } }
                    Rectangle {
                        id: frame
                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
                        height: root.cardWidth * 0.65 - 12
                        color: Style.surface
                        radius: Style.radiusSmall
                        clip: true
                        Image {
                            id: preview
                            anchors.fill: parent
                            source: card.modelData.preview
                            sourceSize: Qt.size(720, 480)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: preview.status !== Image.Ready
                            text: "Sin vista previa"
                            color: Style.muted
                            font.family: Style.font
                            font.pixelSize: Style.fontSmall
                        }
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: 20; top: frame.bottom; topMargin: 18 }
                        text: card.modelData.name
                        textFormat: Text.PlainText
                        font.family: Style.font
                        font.pixelSize: Style.fontLarge
                        color: card.active ? Style.accent : Style.fg
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 20; top: frame.bottom; topMargin: 21 }
                        text: card.modelData.id === root.catalog.current ? "Actual" : ""
                        color: Style.muted
                        font.family: Style.font
                        font.pixelSize: Style.fontSmall
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selected = card.index
                        onClicked: { root.selected = card.index; root.activate() }
                    }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Último fondo guardado de cada perfil · ← →: elegir · Enter: aplicar · Esc: cerrar"
            color: Style.muted
            font.family: Style.font
            font.pixelSize: Style.fontSmall
        }
    }
}
