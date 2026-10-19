import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.config

PanelWindow {
    id: editor
    property var slots: []
    signal done()
    anchors { left: true; right: true; top: true; bottom: true }
    color: "#30000000"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "orgm-widget-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    FocusScope {
        id: canvas
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: editor.done()
        Keys.onReturnPressed: editor.done()
        Repeater {
            model: editor.slots
            delegate: Item {
                id: tile
                required property var modelData
                readonly property var slot: modelData
                property bool dragging: false
                property real dragX: 0
                property real dragY: 0
                property real offsetX: 0
                property real offsetY: 0
                visible: slot.enabled
                x: dragging ? dragX : slot.margins.left
                y: dragging ? dragY : slot.margins.top
                width: slot.implicitWidth
                height: slot.implicitHeight
                Accessible.name: slot.widget === "clock" ? "Mover reloj" : "Mover calendario"
                Rectangle {
                    anchors { fill: parent; margins: -5 }
                    radius: 12
                    color: "transparent"
                    border { width: 1; color: Theme.accent }
                }
                Loader {
                    active: editor.visible
                    scale: tile.slot.fit
                    transformOrigin: Item.TopLeft
                    sourceComponent: tile.slot.widget === "clock" ? clock : calendar
                }
                Component { id: clock; DesktopClock {} }
                Component { id: calendar; DesktopCalendar {} }
                MouseArea {
                    id: grab
                    anchors.fill: parent
                    cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    acceptedButtons: Qt.LeftButton
                    onPressed: mouse => {
                        tile.offsetX = mouse.x
                        tile.offsetY = mouse.y
                        tile.dragX = tile.x
                        tile.dragY = tile.y
                        tile.dragging = true
                    }
                    onPositionChanged: mouse => {
                        if (!tile.dragging) return
                        const point = grab.mapToItem(canvas, mouse.x, mouse.y)
                        tile.dragX = Math.max(0, Math.min(canvas.width - tile.width - 8, point.x - tile.offsetX))
                        tile.dragY = Math.max(0, Math.min(canvas.height - tile.height - 8, point.y - tile.offsetY))
                    }
                    onReleased: {
                        if (!tile.dragging) return
                        Settings.savePosition(tile.slot.widget, editor.screen.name, tile.dragX, tile.dragY)
                        tile.dragging = false
                    }
                    onCanceled: tile.dragging = false
                }
            }
        }
        Rectangle {
            id: toolbar
            z: 10
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 16 }
            width: Math.min(460, parent.width - 24)
            height: contents.implicitHeight + 24
            radius: 12
            color: Theme.surface
            Column {
                id: contents
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8
                Row {
                    width: parent.width
                    spacing: 8
                    Text {
                        width: parent.width - 108
                        height: 36
                        verticalAlignment: Text.AlignVCenter
                        text: "Editar widgets"
                        font { family: Theme.font; pixelSize: 18; weight: Font.DemiBold }
                        color: Theme.ink
                    }
                    EditorButton { width: 100; text: "Terminar"; onClicked: editor.done() }
                }
                Row {
                    width: parent.width
                    spacing: 8
                    EditorButton {
                        width: (parent.width - 8) / 2
                        highlighted: Settings.values.clockEnabled !== false
                        text: highlighted ? "Reloj: visible" : "Reloj: oculto"
                        onClicked: Settings.setEnabled("clock", !highlighted)
                    }
                    EditorButton {
                        width: (parent.width - 8) / 2
                        highlighted: Settings.values.calendarEnabled !== false
                        text: highlighted ? "Calendario: visible" : "Calendario: oculto"
                        onClicked: Settings.setEnabled("calendar", !highlighted)
                    }
                }
                Text {
                    width: parent.width
                    text: Settings.errorText || (Settings.saving ? "Guardando…" : "Arrastra para mover. Esc para terminar.")
                    wrapMode: Text.WordWrap
                    font { family: Theme.font; pixelSize: 12 }
                    color: Settings.errorText ? "#ed8796" : Theme.inkDim
                }
            }
        }
    }
    component EditorButton: Button {
        id: button
        height: 36
        Accessible.name: text
        contentItem: Text {
            text: button.text
            font { family: Theme.font; pixelSize: 13 }
            color: button.highlighted ? Theme.surface : Theme.ink
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: 8
            color: button.highlighted ? Theme.accent : button.hovered ? Theme.tileHover : "transparent"
            opacity: button.down ? .8 : 1
            border { width: button.activeFocus ? 2 : 0; color: Theme.ink }
        }
    }
}
