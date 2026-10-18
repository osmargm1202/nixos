import QtQuick
import QtQuick.Controls
import Quickshell
import qs.config
import qs.components

MenuWindow {
    id: root
    layerNamespace: "orgm-audio"
    property var catalog: ({})
    readonly property string choice: ""
    readonly property bool confirming: false
    signal chosen(string value)
    function snapshot() {
        return { outputs: AudioModel.outputs.map(n => ({ id: n.id, name: n.name,
                    volume: n.audio.volume, muted: n.audio.muted, selected: n === AudioModel.sink })),
                 inputs: AudioModel.inputs.map(n => ({ id: n.id, name: n.name,
                    volume: n.audio.volume, muted: n.audio.muted, selected: n === AudioModel.source })) }
    }
    screen: Quickshell.screens.find(s => s.name === root.catalog.screen) || Quickshell.screens[0]
    Surface {
        anchors.centerIn: parent
        width: Math.min(700, root.width - 48)
        height: Math.min(root.height - 64, 660)
        radius: Style.radius
        opacity: root.progress
        Column {
            anchors { fill: parent; margins: 24 }
            spacing: 16
            Text { text: "Audio"; color: Style.fg; font.family: Style.font; font.pixelSize: 26 }
            Text { text: "Selecciona la salida y la entrada predeterminadas"; color: Style.muted; font.family: Style.font; font.pixelSize: Style.fontSmall }
            ScrollView {
                width: parent.width
                height: parent.height - 100
                clip: true
                contentWidth: availableWidth
                Column {
                    width: parent.width
                    spacing: 12
                    Repeater {
                        model: [{ title: "Salida", nodes: AudioModel.outputs }, { title: "Micrófono", nodes: AudioModel.inputs }]
                        delegate: Column {
                            id: section
                            required property var modelData
                            width: parent.width
                            spacing: 12
                            Text { text: section.modelData.title; color: Style.accent; font.family: Style.font; font.pixelSize: Style.fontLarge }
                            Text { visible: section.modelData.nodes.length === 0; text: "No hay dispositivos disponibles"; color: Style.muted; font.family: Style.font }
                            Repeater {
                                model: section.modelData.nodes
                                delegate: Rectangle {
                                    id: device
                                    required property var modelData
                                    readonly property bool selected: modelData === (modelData.isSink ? AudioModel.sink : AudioModel.source)
                                    width: section.width
                                    height: 136
                                    color: Style.surface
                                    radius: Style.radiusSmall
                                    border.width: selected ? 1 : 0
                                    border.color: Style.accent
                                    Column {
                                        anchors { fill: parent; margins: 12 }
                                        spacing: 8
                                        Row {
                                            width: parent.width
                                            spacing: 8
                                            MenuButton {
                                                width: parent.width - 110
                                                height: 38
                                                text: (device.selected ? "✓ " : "") + (device.modelData.description || device.modelData.name)
                                                highlighted: device.selected
                                                onClicked: AudioModel.setDefault(device.modelData)
                                            }
                                            MenuButton {
                                                width: 102; height: 38
                                                text: device.modelData.audio.muted ? "Activar" : "Silenciar"
                                                onClicked: AudioModel.mute(device.modelData)
                                            }
                                        }
                                        MenuSlider {
                                            width: parent.width
                                            label: "Volumen"
                                            maximum: 150
                                            level: device.modelData.audio.volume * 100
                                            onAdjusted: percent => AudioModel.volume(device.modelData, percent)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Text { text: "Esc o clic fuera: cerrar"; color: Style.muted; font.family: Style.font; font.pixelSize: Style.fontSmall }
        }
    }
}
