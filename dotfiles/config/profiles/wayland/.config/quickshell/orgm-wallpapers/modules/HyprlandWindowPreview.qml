import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland

// Capture the client itself, never the desktop region behind an overview card.
Item {
    id: root
    property string address: ""
    property bool active: false
    readonly property var toplevel: {
        const target = root.address.replace(/^0x/, "")
        return Hyprland.toplevels.values.find(window => window.address.replace(/^0x/, "") === target) || null
    }
    readonly property bool ready: capture.hasContent
    ScreencopyView {
        id: capture
        anchors.centerIn: parent
        width: sourceSize.width > 0 ? Math.min(parent.width, parent.height * sourceSize.width / sourceSize.height) : parent.width
        height: sourceSize.height > 0 ? Math.min(parent.height, parent.width * sourceSize.height / sourceSize.width) : parent.height
        constraintSize: Qt.size(root.width, root.height)
        captureSource: root.active && root.toplevel ? root.toplevel.wayland : null
        // A switcher needs a single fresh frame, not a stream per window.
        live: false
    }
}
