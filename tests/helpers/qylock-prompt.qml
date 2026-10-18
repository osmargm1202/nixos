// Private test stand-in for a Polkit agent. No authentication or system calls.
import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
    Window {
        visible: true; width: 640; height: 240
        title: "Private test authentication prompt"
        color: "#ddeeff"
        TextInput { id: input; anchors.centerIn: parent; width: 480; height: 40; focus: true }
    }
    IpcHandler {
        target: "private-prompt"
        function text(): string { return input.text }
        function close(): void { Qt.quit() }
    }
    Component.onCompleted: Quickshell.watchFiles = false
}
