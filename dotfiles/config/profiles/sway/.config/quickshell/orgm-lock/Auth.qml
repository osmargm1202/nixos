// SPDX-License-Identifier: GPL-3.0-only
// qylock-compatible interface; provenance in NOTICE.md.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Item {
    id: auth
    required property var settings
    property bool secure: false
    property bool authenticated: false
    property bool submitting: false
    property string pendingPassword: ""
    property string feedback: ""
    signal accepted()

    readonly property var config: settings.config || ({})
    readonly property var userModel: users
    readonly property var sessionModel: sessions
    readonly property var keyboard: keyboardShim
    readonly property var sddm: api
    ListModel {
        id: users
        property string lastUser: auth.settings.user || ""
        property int lastIndex: 0
        function rowCount() { return count }
        function index(row, column) { return row }
        function data(row, role) {
            const user = get(row)
            return user ? (role === Qt.UserRole + 2 ? user.realName : user.name) : ""
        }
    }
    ListModel {
        id: sessions
        property int lastIndex: 0
        function rowCount() { return count }
        function index(row, column) { return row }
        function data(row, role) { return row === 0 ? "Sway" : "" }
    }
    QtObject { id: keyboardShim; property bool numLock: false }
    QtObject {
        id: api
        signal loginSucceeded()
        signal loginFailed()
        readonly property string hostName: auth.settings.host || "localhost"
        readonly property bool fingerprintReady: !!auth.settings.fingerprint
        readonly property bool fingerprintHint: fingerprintReady
        property string fingerprintState: "idle"
        property bool fingerprintUnlock: false
        function surfaceRevealed() {}
        function login(user, password, sessionIndex) {
            // A lock always authenticates its owning user, never a selected
            // account from a greeter theme. No password is logged or persisted.
            if (!auth.secure || auth.authenticated || auth.submitting) return
            if (!password) {
                auth.feedback = "Escribe tu contraseña o utiliza la huella."
                return
            }
            auth.pendingPassword = password
            auth.submitting = true
            auth.feedback = "Validando…"
            passwordPam.start()
        }
        function suspend() { if (auth.secure) Quickshell.execDetached(["systemctl", "suspend"]) }
        function reboot() { if (auth.secure) Quickshell.execDetached(["systemctl", "reboot"]) }
        function powerOff() { if (auth.secure) Quickshell.execDetached(["systemctl", "poweroff"]) }
    }
    function success(fingerprint) {
        if (!secure || authenticated) return
        authenticated = true
        submitting = false
        pendingPassword = ""
        api.fingerprintUnlock = fingerprint
        api.fingerprintState = "success"
        passwordPam.abort()
        fingerprintPam.abort()
        api.loginSucceeded()
        accepted()
    }
    PamContext {
        id: passwordPam
        user: auth.settings.user || ""
        config: "orgm-qylock-pw"
        configDirectory: auth.settings.pamDirectory || ""
        onResponseRequiredChanged: {
            if (responseRequired && auth.pendingPassword !== "") {
                const password = auth.pendingPassword
                auth.pendingPassword = ""
                respond(password)
            }
        }
        onCompleted: result => {
            auth.pendingPassword = ""
            auth.submitting = false
            if (result === PamResult.Success) auth.success(false)
            else if (!auth.authenticated) {
                auth.feedback = "Contraseña incorrecta o autenticación no disponible."
                api.loginFailed()
            }
        }
        onError: error => {
            if (auth.authenticated) return
            auth.pendingPassword = ""
            auth.submitting = false
            auth.feedback = "No se pudo autenticar. Vuelve a intentarlo."
            api.loginFailed()
        }
    }
    PamContext {
        id: fingerprintPam
        user: auth.settings.user || ""
        config: "orgm-qylock-fp"
        configDirectory: auth.settings.pamDirectory || ""
        onResponseRequiredChanged: if (responseRequired) respond("")
        onCompleted: result => {
            if (auth.authenticated || !auth.secure) return
            if (result === PamResult.Success) auth.success(true)
            else {
                api.fingerprintState = "fail"
                fingerprintRetry.restart()
            }
        }
        onError: error => {
            if (!auth.authenticated) api.fingerprintState = "unavailable"
        }
    }
    Timer {
        id: fingerprintRetry
        interval: 1500
        onTriggered: if (auth.secure && !auth.authenticated && auth.settings.fingerprint) {
            api.fingerprintState = "scanning"
            fingerprintPam.start()
        }
    }
    onSecureChanged: {
        if (secure && settings.fingerprint) fingerprintRetry.start()
        else if (!secure) {
            pendingPassword = ""
            passwordPam.abort()
            fingerprintPam.abort()
            fingerprintRetry.stop()
        }
    }
    function updateUser() {
        if (!settings.user) return
        users.clear()
        users.append({name: settings.user, realName: settings.realName || settings.user,
            icon: settings.icon || "", homeDir: settings.home || ""})
    }
    onSettingsChanged: updateUser()
    Component.onCompleted: {
        updateUser()
        sessions.append({name: "Sway", file: "sway.desktop"})
    }
}
