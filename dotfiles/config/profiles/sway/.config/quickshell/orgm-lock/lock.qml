// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import "keyboard"
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
    property bool clockVisible: Quickshell.env("ORGM_QY_IDLE_CLOCK") === "1"
    property int surfaceCount: 0
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
            if (ready.path) ready.setText("unlocked")
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
                theme: root.settings.id || "", fallback: root.emergency, clock: root.clockVisible, user: root.settings.user || "",
                surfaces: root.surfaceCount,
                submitting: backendAuth.submitting, feedback: backendAuth.feedback,
                passwordWaiting: backendAuth.passwordWaiting, passwordActive: backendAuth.passwordActive,
                promptCount: backendAuth.promptCount})
        }
        // This only reveals the authentication UI; it never unlocks.
        function dismissClock(): void { root.clockVisible = false }
    }
    WlSessionLock {
        id: session
        locked: root.configured && !root.ending
        onSecureChanged: {
            if (secure && ready.path) ready.setText("secure")
        }
        surface: WlSessionLockSurface {
            color: "black"
            Component.onCompleted: root.surfaceCount += 1
            Component.onDestruction: root.surfaceCount -= 1
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onWheel: event => { event.accepted = true }
            }
            Loader {
                id: theme
                anchors.fill: parent
                // Acquire/paint the minimal secure surface before loading a
                // potentially heavy skin/video; before-sleep must not wait on it.
                active: session.secure && root.configured && !root.emergency
                source: root.settings.themeUrl ? root.settings.themeUrl + "/Main.qml" : ""
                onLoaded: if (root.clockVisible) idleClock.forceActiveFocus(); else item.forceActiveFocus()
            }
            Fallback {
                anchors.fill: parent
                anchors.bottomMargin: fallbackKeyboard.reservedHeight
                auth: backendAuth
                visible: root.emergency || theme.status !== Loader.Ready
            }
            AuthKeyboard {
                id: fallbackKeyboard
                anchors.fill: parent
                visible: root.emergency || theme.status !== Loader.Ready
                onVisibleChanged: if (!visible) hide()
            }
            FlipClock {
                id: idleClock
                anchors.fill: parent
                visible: root.clockVisible && session.secure
                twelveHour: Quickshell.env("ORGM_CLOCK_12H") === "1"
                z: 100
                onVisibleChanged: {
                    if (visible) forceActiveFocus()
                    else if (theme.item) theme.item.forceActiveFocus()
                }
                onDismissed: {
                    root.clockVisible = false
                    if (theme.item) theme.item.forceActiveFocus()
                }
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
