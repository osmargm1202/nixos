import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "black"
            FlipClock { anchors.fill: parent; twelveHour: Quickshell.env("ORGM_CLOCK_12H") === "1"; onDismissed: Qt.quit() }
        }
    }
}
