// SPDX-License-Identifier: GPL-3.0-only
// Non-locking, non-interactive theme preview. PAM cannot run (secure=false).
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    property var settings: ({})
    property var candidates: []
    readonly property var sddm: backendAuth.sddm
    readonly property var config: backendAuth.config
    readonly property var userModel: backendAuth.userModel
    readonly property var sessionModel: backendAuth.sessionModel
    readonly property var keyboard: backendAuth.keyboard
    Auth { id: backendAuth; settings: root.settings; secure: false }
    FileView { id: data; path: Quickshell.env("ORGM_LOCK_DATA"); blockLoading: true }
    Window {
        id: window
        visible: true
        width: 1280; height: 720
        title: "Qylock — VISTA PREVIA, NO BLOQUEA"
        color: "black"
        Loader {
            id: theme
            anchors.fill: parent
            source: root.settings.themeUrl ? root.settings.themeUrl + "/Main.qml" : ""
            enabled: false
        }
        Rectangle {
            anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
            width: label.implicitWidth + 32; height: 36; color: "#dd081422"
            Text {
                id: label; anchors.centerIn: parent
                text: "VISTA PREVIA · NO BLOQUEA · " + (root.settings.id || "")
                color: "white"; font.pixelSize: 14; textFormat: Text.PlainText
            }
        }
    }
    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; onActivated: Qt.quit() }
    IpcHandler {
        target: "lock-preview"
        function load(id: string): bool {
            const item = root.candidates.find(t => t.id === id)
            if (!item) return false
            root.settings = item
            return true
        }
        function status(): string {
            return JSON.stringify({theme: root.settings.id || "", ready: theme.status === Loader.Ready,
                error: theme.status === Loader.Error})
        }
        function close(): void { Qt.quit() }
    }
    Component.onCompleted: {
        Quickshell.watchFiles = false
        const info = JSON.parse(data.text())
        candidates = info.candidates
        settings = candidates[0]
    }
}
