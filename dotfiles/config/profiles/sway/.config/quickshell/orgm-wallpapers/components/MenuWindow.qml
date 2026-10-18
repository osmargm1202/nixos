import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Adapted from shadowofdominance/swaydots; see ../NOTICE.md.
PanelWindow {
    id: win
    property bool open: false
    property bool busy: false
    property real progress: open ? 1 : 0
    signal keyPressed(var event)
    signal dismissed()

    function show() { open = true }
    function close() {
        if (busy || !open) return
        open = false
        closeTimer.start()
    }

    Behavior on progress {
        NumberAnimation { duration: Style.animMed; easing.type: Easing.OutCubic }
    }
    Timer {
        id: closeTimer
        interval: Style.animMed + 40
        onTriggered: win.dismissed()
    }

    visible: open || progress > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "orgm-wallpapers"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onOpenChanged: if (open) keys.forceActiveFocus()

    Rectangle {
        anchors.fill: parent
        color: Style.scrim
        opacity: win.progress
        MouseArea { anchors.fill: parent; onClicked: win.close() }
    }
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                win.close()
                event.accepted = true
            } else if (!win.busy) {
                win.keyPressed(event)
            }
        }
    }
}
