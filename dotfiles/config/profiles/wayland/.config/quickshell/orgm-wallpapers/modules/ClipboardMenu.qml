import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

MenuWindow {
    id: root
    layerNamespace: "orgm-clipboard"
    property var catalog: ({})
    property var entries: catalog.items || []
    property string filter: ""
    readonly property var filtered: entries.filter(item => item.name.toLowerCase().includes(filter.toLowerCase()))
    property int selected: 0
    readonly property string choice: filtered[selected] ? filtered[selected].id : ""
    readonly property bool confirming: false
    property string errorText: ""
    signal chosen(string value)
    screen: Quickshell.screens.find(s => s.name === root.catalog.screen) || Quickshell.screens[0]
    onFilterChanged: selected = 0
    onSelectedChanged: history.positionViewAtIndex(selected, ListView.Contain)
    onOpenChanged: if (open) Qt.callLater(() => search.forceActiveFocus())
    function reset() {
        search.text = ""
        filter = ""
        selected = 0
        errorText = ""
        entries = catalog.items || []
    }
    function move(delta) { selected = Math.max(0, Math.min(filtered.length - 1, selected + delta)) }
    function activate() { if (open && choice) chosen(choice) }
    function remove() {
        if (choice && !deletion.running) {
            deletion.key = choice
            deletion.command = [catalog.backend, "clipboard-delete", choice]
            deletion.running = true
        }
    }
    Process {
        id: deletion
        property string key: ""
        onExited: (code, status) => {
            if (code === 0) {
                root.entries = root.entries.filter(item => item.id !== key)
                root.selected = Math.max(0, Math.min(root.selected, root.filtered.length - 1))
            } else root.errorText = "No se pudo borrar la entrada"
        }
    }
    Surface {
        anchors.centerIn: parent
        width: Math.min(850, root.width - 48)
        height: Math.min(670, root.height - 64)
        radius: Style.radius
        opacity: root.progress
        Column {
            anchors { fill: parent; margins: 24 }
            spacing: 16
            Text { text: "Portapapeles"; color: Style.fg; font.family: Style.font; font.pixelSize: 26 }
            Rectangle {
                width: parent.width; height: 48; radius: Style.radiusSmall; color: Style.surface
                TextInput {
                    id: search
                    anchors { fill: parent; margins: 12 }
                    color: Style.fg; font.family: Style.font; font.pixelSize: Style.fontNormal
                    clip: true
                    selectByMouse: true
                    onTextChanged: root.filter = text
                    Text { visible: !search.text; text: "Buscar texto o imagen…"; color: Style.muted; font: search.font }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) root.move(1)
                        else if (event.key === Qt.Key_Up) root.move(-1)
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.activate()
                        else if (event.key === Qt.Key_Delete && !text) root.remove()
                        else if (event.key === Qt.Key_Escape) root.close()
                        else return
                        event.accepted = true
                    }
                }
            }
            ListView {
                id: history
                width: parent.width
                height: parent.height - 150
                spacing: 8
                clip: true
                model: root.filtered
                delegate: Rectangle {
                    id: entry
                    required property int index
                    required property var modelData
                    width: history.width
                    height: modelData.preview ? 108 : 56
                    radius: Style.radiusSmall
                    color: root.selected === index ? Style.surface : "transparent"
                    border.width: root.selected === index ? 1 : 0
                    border.color: Style.accent
                    Image {
                        id: thumbnail
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 8 }
                        width: entry.modelData.preview ? 140 : 0
                        source: entry.modelData.preview
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    Text {
                        anchors { left: thumbnail.right; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 12 }
                        text: entry.modelData.name
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        color: Style.fg; font.family: Style.font; font.pixelSize: Style.fontNormal
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.selected = entry.index; root.activate() } }
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.filtered.length === 0
                    text: root.entries.length ? "Sin coincidencias" : "El historial está vacío"
                    color: Style.muted; font.family: Style.font
                }
            }
            Text { text: root.errorText || "↑ ↓: elegir · Enter: copiar · Supr con búsqueda vacía: borrar · Esc: cerrar"; color: root.errorText ? Style.error : Style.muted; font.family: Style.font; font.pixelSize: Style.fontSmall }
        }
    }
}
