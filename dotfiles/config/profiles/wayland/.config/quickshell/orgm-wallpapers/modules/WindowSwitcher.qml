import QtQuick
import Quickshell
import qs.config
import qs.components

MenuWindow {
    id: root
    layerNamespace: "orgm-windows"
    animationDuration: 100
    property var catalog: ({})
    readonly property var groups: catalog.groups || []
    readonly property var windows: groups.reduce((all, group) => all.concat(group.items), [])
    property int selected: 0
    readonly property string choice: windows[selected] ? windows[selected].id : ""
    readonly property string selectedWorkspace: windows[selected] ? windows[selected].workspace : ""
    readonly property bool confirming: false
    readonly property int columns: Math.max(1, Math.min(3, Math.ceil(Math.sqrt(groups.length))))
    readonly property int rows: Math.max(1, Math.ceil(groups.length / columns))
    readonly property real groupWidth: (width - 80 - (columns - 1) * 20) / columns
    readonly property real groupHeight: Math.max(220, Math.min(groupWidth * 0.68 + 68,
        (height - 180 - (rows - 1) * 20) / rows))
    signal chosen(string value)
    screen: Quickshell.screens.find(s => s.name === root.catalog.screen) || Quickshell.screens[0]
    onCatalogChanged: {
        const ordered = (catalog.groups || []).reduce((all, group) => all.concat(group.items), [])
        const focused = Math.max(0, ordered.findIndex(window => window.focused))
        const delta = catalog.direction === undefined ? 1 : catalog.direction
        selected = ordered.length > 1 ? ((focused + delta) % ordered.length + ordered.length) % ordered.length : 0
    }
    function move(delta) { if (windows.length) selected = (selected + delta + windows.length) % windows.length }
    function moveGroup(delta) {
        if (!groups.length) return
        const current = groups.findIndex(group => group.name === selectedWorkspace)
        const target = groups[(current + delta + groups.length) % groups.length]
        selected = windows.findIndex(window => window.id === target.items[0].id)
    }
    function activate() { if (open && choice) chosen(choice) }
    function activateWorkspace(name) { if (open && name) chosen("workspace:" + name) }
    function highlightWindow(id) { selected = windows.findIndex(window => window.id === id) }
    function selectWindow(id) { highlightWindow(id); activate() }
    function snapshot() {
        return { columns, rows, groups: Array.from({ length: workspaces.count }, (_, index) => workspaces.itemAt(index).snapshot()) }
    }
    onSelectedChanged: {
        const index = groups.findIndex(group => group.name === selectedWorkspace)
        const row = Math.max(0, Math.floor(index / columns))
        overview.contentY = Math.min(Math.max(0, row * (groupHeight + 20)), Math.max(0, overview.contentHeight - overview.height))
    }
    onKeyPressed: event => {
        switch (event.key) {
        case Qt.Key_Tab: move(event.modifiers & Qt.ShiftModifier ? -1 : 1); break
        case Qt.Key_Backtab: move(-1); break
        case Qt.Key_Right: case Qt.Key_L: move(1); break
        case Qt.Key_Left: case Qt.Key_H: move(-1); break
        case Qt.Key_Up: case Qt.Key_K: moveGroup(-columns); break
        case Qt.Key_Down: case Qt.Key_J: moveGroup(columns); break
        case Qt.Key_Space: if (!event.isAutoRepeat) activateWorkspace(selectedWorkspace); break
        case Qt.Key_Return: case Qt.Key_Enter: if (!event.isAutoRepeat) activate(); break
        }
        event.accepted = true
    }
    onKeyReleased: event => { if (event.key === Qt.Key_Alt) activate() }
    Column {
        anchors.centerIn: parent
        width: root.width - 80
        spacing: 20
        opacity: root.progress
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Escritorios y ventanas"; color: Style.fg; font.family: Style.font; font.pixelSize: 26 }
        Flickable {
            id: overview
            width: parent.width
            height: Math.max(100, Math.min(root.height - 180, workspaceGrid.implicitHeight))
            contentWidth: width
            contentHeight: workspaceGrid.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Grid {
                id: workspaceGrid
                columns: root.columns
                spacing: 20
                Repeater {
                    id: workspaces
                    model: root.groups
                    delegate: Rectangle {
                        id: workspace
                        required property var modelData
                        required property int index
                        readonly property int windowColumns: Math.max(1, Math.min(3, Math.ceil(Math.sqrt(modelData.items.length))))
                        readonly property int windowRows: Math.max(1, Math.ceil(modelData.items.length / windowColumns))
                        width: root.groupWidth
                        height: root.groupHeight
                        color: Style.panel
                        radius: Style.radius
                        border.width: root.selectedWorkspace === modelData.name ? 2 : 1
                        border.color: root.selectedWorkspace === modelData.name ? Style.accent : Style.outline
                        function snapshot() {
                            const point = mapToItem(null, 0, 0)
                            return { name: modelData.name, x: point.x, y: point.y, width, height,
                                windows: Array.from({ length: windowCards.count }, (_, i) => {
                                    const card = windowCards.itemAt(i)
                                    const position = card.mapToItem(null, 0, 0)
                                    return { id: card.modelData.id, x: position.x, y: position.y, width: card.width, height: card.height,
                                        previewReady: card.previewReady }
                                }) }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: root.highlightWindow(workspace.modelData.items[0].id)
                            onPositionChanged: root.highlightWindow(workspace.modelData.items[0].id)
                            onClicked: root.activateWorkspace(workspace.modelData.name)
                        }
                        Text {
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                            text: (workspace.modelData.name === "__i3_scratch" ? "Scratchpad" : "Escritorio " + workspace.modelData.name)
                                + (workspace.modelData.focused ? " · Actual" : "")
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Style.fg; font.family: Style.font; font.pixelSize: Style.fontLarge
                        }
                        Flickable {
                            id: windowArea
                            anchors { top: parent.top; topMargin: 56; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                            contentWidth: width
                            contentHeight: windowGrid.implicitHeight
                            clip: true
                            interactive: contentHeight > height
                            boundsBehavior: Flickable.StopAtBounds
                            Grid {
                                id: windowGrid
                                columns: workspace.windowColumns
                                spacing: 10
                                Repeater {
                                    id: windowCards
                                    model: workspace.modelData.items
                                    delegate: Rectangle {
                                        id: card
                                        required property var modelData
                                        readonly property bool previewReady: nativePreview.item ? nativePreview.item.ready : preview.status === Image.Ready
                                        width: (windowArea.width - (workspace.windowColumns - 1) * 10) / workspace.windowColumns
                                        height: Math.max(104, (windowArea.height - (workspace.windowRows - 1) * 10) / workspace.windowRows)
                                        color: Style.surface
                                        radius: Style.radiusSmall
                                        border.width: root.choice === modelData.id ? 2 : 0
                                        border.color: Style.accent
                                        Image {
                                            id: preview
                                            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 6 }
                                            height: parent.height - 52
                                            source: card.modelData.preview
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            cache: false
                                            visible: !Style.hyprlandSession
                                        }
                                        Loader {
                                            id: nativePreview
                                            anchors.fill: preview
                                            active: Style.hyprlandSession && root.visible
                                            source: active ? "HyprlandWindowPreview.qml" : ""
                                            onLoaded: {
                                                item.address = Qt.binding(() => card.modelData.id)
                                                item.active = Qt.binding(() => root.open)
                                            }
                                        }
                                        Text {
                                            anchors.centerIn: preview
                                            width: preview.width - 8
                                            text: "Vista previa pendiente"
                                            visible: !card.previewReady
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            color: Style.muted; font.family: Style.font; font.pixelSize: Style.fontSmall
                                        }
                                        Text {
                                            anchors { top: preview.bottom; left: parent.left; right: parent.right; margins: 8 }
                                            text: card.modelData.name || card.modelData.app
                                            textFormat: Text.PlainText
                                            elide: Text.ElideRight
                                            color: Style.fg; font.family: Style.font; font.pixelSize: Style.fontSmall
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onEntered: root.highlightWindow(card.modelData.id)
                                            onPositionChanged: root.highlightWindow(card.modelData.id)
                                            onClicked: root.selectWindow(card.modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.windows.length ? "Clic en escritorio: abrir · clic en ventana: enfocar · Alt+Tab o ← →: recorrer · Esc: cancelar" : "No hay ventanas abiertas"
            color: Style.muted; font.family: Style.font; font.pixelSize: Style.fontSmall
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Enter o soltar Alt: ventana · Espacio: escritorio · "
                + (Style.hyprlandSession ? "vistas previas de cada ventana" : "miniaturas del último contenido visible")
            color: Style.muted; font.family: Style.font; font.pixelSize: Style.fontSmall
        }
    }
}
