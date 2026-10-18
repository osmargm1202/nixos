import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.components

// Carousel adapted from shadowofdominance/swaydots; see ../NOTICE.md.
MenuWindow {
    id: root
    property var catalog: ({})
    readonly property var files: catalog.items || []
    readonly property int count: files.length
    property int current: 0
    property real pos: 0
    property bool snap: false
    property string errorText: ""
    readonly property real cardH: Math.min(height * 0.5, 520)
    readonly property real cardWide: cardH * 1.65
    readonly property real cardNarrow: cardH * 0.35
    readonly property real cardGap: Style.spacing

    screen: Quickshell.screens.find(s => s.name === root.catalog.screen) || Quickshell.screens[0]
    onCurrentChanged: pos = current
    Behavior on pos {
        enabled: !root.snap
        NumberAnimation { duration: Style.animSlow; easing.type: Easing.OutCubic }
    }

    function step(n) {
        if (!busy && count > 0) current = Math.max(0, Math.min(count - 1, current + n))
    }
    function syncToSaved() {
        const index = files.findIndex(item => item.path === catalog.current)
        snap = true
        current = Math.max(0, index)
        pos = current
        snap = false
    }
    function apply() {
        if (count === 0 || busy) return
        errorText = ""
        busy = true
        applyProc.command = [catalog.backend, "select", files[current].id]
        applyProc.running = true
    }
    onKeyPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_H: step(-1); break
        case Qt.Key_Right:
        case Qt.Key_L: step(1); break
        case Qt.Key_Home: current = 0; break
        case Qt.Key_End: current = Math.max(0, count - 1); break
        case Qt.Key_Return:
        case Qt.Key_Enter: apply(); break
        default: return
        }
        event.accepted = true
    }

    IpcHandler {
        target: "lock-themes"
        function status(): string {
            return JSON.stringify({current: root.current, count: root.count, busy: root.busy,
                selected: root.count ? root.files[root.current].path : "",
                profile: root.catalog.profile, screen: root.screen ? root.screen.name : "",
                error: root.errorText})
        }
        function close(): void { root.close() }
    }
    Process {
        id: applyProc
        stderr: StdioCollector { id: applyErrors }
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            if (exitCode === 0 && exitStatus === 0) root.close()
            else root.errorText = (applyErrors.text.trim() || "No se pudo aplicar el tema de inicio y bloqueo.").slice(0, 1200)
        }
        onRunningChanged: if (!running && root.busy) launchGuard.restart()
    }
    Timer {
        id: launchGuard
        interval: 150
        onTriggered: {
            if (root.busy && !applyProc.running) {
                root.busy = false
                root.errorText = "No se pudo iniciar el cambio de tema."
            }
        }
    }
    // PanelWindow is not a QQuickItem: a bare WheelHandler has no item to
    // receive pointer events. This visual surface covers the menu, but does
    // not accept mouse buttons, so card clicks and outside-click still work.
    MouseArea {
        id: wheelInput
        anchors.fill: parent
        z: 100
        acceptedButtons: Qt.NoButton
        scrollGestureEnabled: true
        property real remainder: 0
        property bool pixelMode: false
        property double lastWheel: 0
        onWheel: event => {
            event.accepted = true
            if (root.busy) return
            const pixels = event.angleDelta.x === 0 && event.angleDelta.y === 0
            const delta = pixels ? (event.pixelDelta.y || event.pixelDelta.x)
                                 : (event.angleDelta.y || event.angleDelta.x)
            if (!delta) return
            const now = Date.now()
            if (pixels !== pixelMode || now - lastWheel > 250 || remainder * delta < 0)
                remainder = 0
            pixelMode = pixels
            lastWheel = now
            remainder += delta
            const unit = pixels ? 40 : 120
            const steps = Math.trunc(remainder / unit)
            if (steps) {
                root.step(-steps)
                remainder -= steps * unit
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: carousel.top
        anchors.bottomMargin: 30
        text: "Inicio y bloqueo · Qylock"
        textFormat: Text.PlainText
        color: Style.fg
        font.family: Style.font
        font.pixelSize: Style.fontLarge
        opacity: root.progress
    }
    Item {
        id: carousel
        width: root.width
        height: root.cardH
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: (1 - root.progress) * 40
        opacity: root.progress
        readonly property real cx: width / 2

        Repeater {
            model: root.files
            delegate: ClippingRectangle {
                id: card
                required property int index
                required property var modelData
                readonly property real hat: Math.max(0, 1 - Math.abs(index - root.pos))
                readonly property real lo: Math.floor(root.pos)
                readonly property real fr: root.pos - lo
                readonly property real widen: (lo < index ? 1 - fr : 0) + (lo + 1 < index ? fr : 0)
                readonly property real slot: root.cardNarrow + root.cardGap
                readonly property real mid: x + width / 2
                readonly property real edgeDist: Math.min(mid, root.width - mid)

                width: root.cardNarrow + (root.cardWide - root.cardNarrow) * hat
                height: root.cardH
                x: carousel.cx - root.cardWide / 2 + (index - root.pos) * slot
                   + (root.cardWide - root.cardNarrow) * widen
                visible: x + width > -40 && x < root.width + 40
                radius: Style.radius
                color: Style.surface
                border.width: Style.borderWidth * hat
                border.color: Style.accent
                opacity: Math.max(0, Math.min(1, edgeDist / (root.width * 0.16))) * (0.7 + 0.3 * hat)

                Text {
                    anchors.centerIn: parent
                    text: "Vista previa no disponible"
                    textFormat: Text.PlainText
                    color: Style.muted
                    font.family: Style.font
                    font.pixelSize: Style.fontSmall
                    visible: preview.status === Image.Error
                }
                Image {
                    id: preview
                    anchors.fill: parent
                    source: card.visible ? card.modelData.url : ""
                    sourceSize: Qt.size(1200, 800)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Style.animMed } }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !root.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (card.index === root.current) root.apply()
                        else root.current = card.index
                    }
                }
            }
        }
    }
    Surface {
        id: nameTag
        visible: root.count > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: carousel.bottom
        anchors.topMargin: 26
        width: Math.min(root.width - 48, nameText.implicitWidth + 36)
        height: 40
        opacity: root.progress
        Text {
            id: nameText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 36)
            elide: Text.ElideRight
            text: (root.current + 1) + " / " + root.count + "   "
                  + (root.count > 0 ? root.files[root.current].name : "")
            textFormat: Text.PlainText
            color: Style.fg
            font.family: Style.font
            font.pixelSize: Style.fontNormal
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: nameTag.bottom
        anchors.topMargin: 12
        opacity: root.progress * 0.85
        text: root.busy ? "Aplicando…" : "← → / rueda: elegir     Enter: aplicar a SDDM y bloqueo     Esc: cerrar"
        textFormat: Text.PlainText
        color: Style.muted
        font.family: Style.font
        font.pixelSize: Style.fontSmall
    }
    Text {
        visible: root.count === 0
        anchors.centerIn: parent
        width: root.width - 64
        text: "El catálogo Qylock no está instalado."
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: Style.fg
        font.family: Style.font
        font.pixelSize: Style.fontLarge
        opacity: root.progress
    }
    Text {
        visible: root.errorText !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: nameTag.bottom
        anchors.topMargin: 48
        width: Math.min(root.width - 64, 900)
        text: root.errorText
        textFormat: Text.PlainText
        maximumLineCount: 3
        elide: Text.ElideRight
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        color: Style.error
        font.family: Style.font
        font.pixelSize: Style.fontNormal
        opacity: root.progress
    }
}
