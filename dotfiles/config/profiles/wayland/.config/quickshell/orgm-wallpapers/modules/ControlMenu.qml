import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

MenuWindow {
    id: root
    layerNamespace: "orgm-control"
    property var catalog: ({})
    property var state: catalog.state || ({})
    property string errorText: ""
    readonly property string choice: ""
    readonly property bool confirming: false
    signal chosen(string value)
    function reset() { state = catalog.state || {}; errorText = "" }
    screen: Quickshell.screens.find(s => s.name === root.catalog.screen) || Quickshell.screens[0]
    function action(name, value) {
        if (update.running) return
        update.command = [catalog.backend, "control-action", name, value === undefined ? "" : String(value)]
        update.running = true
    }
    Process {
        id: update
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.state = JSON.parse(text); root.errorText = "" }
                catch (error) { root.errorText = "No se pudo actualizar el control" }
            }
        }
        onExited: (code, status) => { if (code !== 0) root.errorText = "No se pudo aplicar el cambio" }
    }
    Timer {
        interval: 2000; repeat: true; running: root.open
        onTriggered: if (!update.running) { update.command = [root.catalog.backend, "control-state"]; update.running = true }
    }
    Timer {
        id: brightness
        property int pending: 50
        interval: 120
        onTriggered: if (update.running) restart(); else root.action("brightness", pending)
    }
    Surface {
        anchors.centerIn: parent
        width: Math.min(660, root.width - 48)
        height: Math.min(760, root.height - 48)
        radius: Style.radius
        opacity: root.progress
        ScrollView {
            anchors { fill: parent; margins: 28 }
            contentWidth: availableWidth
            clip: true
          Column {
            width: parent.width
            spacing: 18
            Text { text: "Centro de control"; color: Style.fg; font.family: Style.font; font.pixelSize: 26 }
            MenuSlider {
                width: parent.width
                label: "Brillo"
                minimum: 5
                enabled: root.state.brightness !== null && root.state.brightness !== undefined
                level: root.state.brightness || 5
                onAdjusted: percent => { brightness.pending = Math.round(percent); brightness.restart() }
            }
            Row {
                width: parent.width
                spacing: 12
                MenuSlider {
                    width: parent.width - 126
                    label: "Volumen"
                    maximum: 150
                    enabled: AudioModel.sink !== null
                    level: AudioModel.sink && AudioModel.sink.audio ? AudioModel.sink.audio.volume * 100 : 0
                    onAdjusted: percent => AudioModel.volume(AudioModel.sink, percent)
                }
                MenuButton {
                    width: 114
                    text: AudioModel.sink && AudioModel.sink.audio && AudioModel.sink.audio.muted ? "Activar" : "Silenciar"
                    enabled: AudioModel.sink !== null
                    onClicked: AudioModel.mute(AudioModel.sink)
                }
            }
            Grid {
                columns: 2
                spacing: 12
                width: parent.width
                MenuButton { width: (parent.width - 12) / 2; text: "󰊴 Gaming"; highlighted: root.state.gaming === true; onClicked: root.action("gaming") }
                MenuButton { width: (parent.width - 12) / 2; text: "󰂛 No molestar"; highlighted: root.state.dnd === true; onClicked: root.action("dnd") }
                MenuButton { width: (parent.width - 12) / 2; text: "󰅶 Caffeine"; enabled: root.state.caffeineAvailable === true; highlighted: root.state.caffeine === true; onClicked: root.action("caffeine") }
                MenuButton { width: (parent.width - 12) / 2; text: "󰏫 Editar widgets"; onClicked: root.chosen("widgets") }
                MenuButton { width: (parent.width - 12) / 2; text: "󰕾 Audio"; onClicked: root.chosen("audio") }
                MenuButton { width: (parent.width - 12) / 2; text: "󰅌 Portapapeles"; onClicked: root.chosen("clipboard") }
                MenuButton { width: (parent.width - 12) / 2; text: " Wi-Fi"; onClicked: root.chosen("wifi") }
                MenuButton { width: (parent.width - 12) / 2; text: " Bluetooth"; onClicked: root.chosen("bluetooth") }
                MenuButton { width: (parent.width - 12) / 2; text: " Perfil visual"; onClicked: root.chosen("profiles") }
                MenuButton { width: (parent.width - 12) / 2; text: "󰌾 Inicio y bloqueo"; onClicked: root.chosen("themes") }
            }
            MenuButton { width: parent.width; text: "󰐥 Sesión y apagado"; onClicked: root.chosen("power") }
            Text { text: root.errorText || "Esc o clic fuera: cerrar"; color: root.errorText ? Style.error : Style.muted; font.family: Style.font; font.pixelSize: Style.fontSmall }
          }
        }
    }
}
