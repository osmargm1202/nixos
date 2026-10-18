// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property var settings: ({})
    property bool configured: false
    property bool authenticated: false
    property bool emergency: false
    property bool ending: false
    readonly property var sddm: backendAuth.sddm
    readonly property var config: backendAuth.config
    readonly property var userModel: backendAuth.userModel
    readonly property var sessionModel: backendAuth.sessionModel
    readonly property var keyboard: backendAuth.keyboard

    FileView { id: data; path: Quickshell.env("ORGM_LOCK_DATA"); blockLoading: true }
    FileView {
        id: ready
        path: Quickshell.env("ORGM_LOCK_READY")
        blockWrites: true; printErrors: false
    }
    Auth {
        id: backendAuth
        settings: root.settings
        secure: session.secure
        onAccepted: {
            root.authenticated = true
            finish.interval = root.settings.id && root.settings.id.startsWith("clockwork/") ? 750 : 100
            finish.start()
        }
    }
    Timer {
        id: finish
        onTriggered: {
            if (!root.authenticated) return
            session.locked = false
            root.ending = true
            Qt.callLater(Qt.quit)
        }
    }
    Shortcut {
        sequence: "F2"
        context: Qt.ApplicationShortcut
        onActivated: root.emergency = !root.emergency
    }
    IpcHandler {
        target: "orgm-lock"
        // Deliberately no IPC unlock/authenticate method.
        function status(): string {
            return JSON.stringify({secure: session.secure, authenticated: root.authenticated,
                theme: root.settings.id || "", fallback: root.emergency, user: root.settings.user || ""})
        }
    }
    WlSessionLock {
        id: session
        locked: root.configured && !root.ending
        onSecureChanged: {
            if (secure && ready.path) ready.setText("secure")
        }
        surface: WlSessionLockSurface {
            color: "black"
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onWheel: event => { event.accepted = true }
            }
            Loader {
                id: theme
                anchors.fill: parent
                active: root.configured && !root.emergency
                source: root.settings.themeUrl ? root.settings.themeUrl + "/Main.qml" : ""
                onLoaded: item.forceActiveFocus()
            }
            Fallback {
                anchors.fill: parent
                auth: backendAuth
                visible: root.emergency || theme.status !== Loader.Ready
            }
            Text {
                anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.margins: 12
                text: "F2 · interfaz de respaldo"
                color: "white"; opacity: 0.65; font.pixelSize: 12
            }
        }
    }
    Component.onCompleted: {
        // Reloading a live session-lock root could abandon the compositor's
        // lock. Production QML is immutable, and automatic reload is disabled.
        Quickshell.watchFiles = false
        try {
            settings = JSON.parse(data.text())
            if (!settings.user || !settings.themeUrl || !settings.pamDirectory)
                throw new Error("Configuración de bloqueo incompleta")
            configured = true
        } catch (error) {
            console.error("No se pudo preparar el bloqueo: " + error)
            if (ready.path) ready.setText("error")
            Qt.callLater(Qt.quit)
        }
    }
}
