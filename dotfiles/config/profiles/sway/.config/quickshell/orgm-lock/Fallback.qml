// SPDX-License-Identifier: GPL-3.0-only
import QtQuick

Rectangle {
    id: fallback
    required property var auth
    color: "#080e18"
    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 440)
        spacing: 20
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(new Date(), "hh:mm")
            color: "#f4f8ff"; font.pixelSize: 72
        }
        Text {
            width: parent.width
            text: "Sesión bloqueada · " + (fallback.auth.settings.user || "")
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            color: "#c1d8eb"; font.pixelSize: 18
        }
        Rectangle {
            width: parent.width; height: 50; radius: 12; color: "#163453"
            TextInput {
                id: password
                anchors.fill: parent; anchors.margins: 14
                color: "#ffffff"; font.pixelSize: 18
                echoMode: TextInput.Password
                selectByMouse: false; focus: true
                enabled: !fallback.auth.submitting
                onEnabledChanged: if (enabled && fallback.visible) forceActiveFocus()
                onAccepted: {
                    fallback.auth.sddm.login("", text, 0)
                    text = ""
                }
            }
        }
        Text {
            width: parent.width
            text: fallback.auth.feedback || "Contraseña y Enter · F2: alternar interfaz de respaldo"
            textFormat: Text.PlainText; wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            color: "#c1d8eb"; font.pixelSize: 14
        }
    }
    onVisibleChanged: if (visible) password.forceActiveFocus()
    Component.onCompleted: if (visible) password.forceActiveFocus()
}
