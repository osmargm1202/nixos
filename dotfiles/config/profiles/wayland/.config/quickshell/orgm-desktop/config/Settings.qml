pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var values: JSON.parse(Quickshell.env("ORGM_WIDGET_SETTINGS") || "{}")
    readonly property bool clock24h: values.clock24h !== false
    readonly property bool clockSeconds: values.clockSeconds === true
    readonly property real clockScale: values.clockScale || 1
    readonly property string clockAccent: "palette"
    readonly property var formatLoc: Qt.locale()
    readonly property date now: clock.date
    property var queue: []
    property string errorText: ""
    readonly property bool saving: writer.running || queue.length > 0
    SystemClock { id: clock; precision: root.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes }
    Process {
        id: reader
        command: [Quickshell.env("ORGM_WIDGET_BACKEND"), "settings"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.values = JSON.parse(text) }
                catch (error) { console.warn("Widgets: configuración no válida; se conserva el estado") }
            }
        }
    }
    function reload() { if (!root.saving) reader.running = true }
    function placement(widget, screen) {
        const row = (values.screens || {})[screen] || {}
        const x = row[widget + "X"], y = row[widget + "Y"]
        return { x: x === undefined ? values[widget + "X"] || 0 : x,
            y: y === undefined ? values[widget + "Y"] || 0 : y,
            free: x !== undefined || y !== undefined }
    }
    function change(patch, screen) {
        // Optimistic placement avoids snapping back between release and fsync.
        const next = Object.assign({}, values)
        if (screen) {
            next.screens = Object.assign({}, next.screens || {})
            next.screens[screen] = Object.assign({}, next.screens[screen] || {}, patch)
        } else Object.assign(next, patch)
        values = next
        queue = [...queue, { patch, screen: screen || "" }]
        flush()
    }
    function savePosition(widget, screen, x, y) {
        const patch = {}
        patch[widget + "X"] = Math.round(x)
        patch[widget + "Y"] = Math.round(y)
        change(patch, screen)
    }
    function setEnabled(widget, enabled) {
        const patch = {}
        patch[widget + "Enabled"] = enabled
        change(patch, "")
    }
    function flush() {
        if (writer.running || queue.length === 0) return
        const next = queue[0]
        writer.command = [Quickshell.env("ORGM_WIDGET_BACKEND"), "update", JSON.stringify(next.patch), next.screen]
        writer.running = true
    }
    Process {
        id: writer
        stdout: StdioCollector {}
        onExited: (code, status) => {
            if (code !== 0) root.errorText = "No se pudo guardar. Revisa widgets.json y sus permisos."
            else root.errorText = ""
            root.queue = root.queue.slice(1)
            if (root.queue.length) root.flush()
            else root.reload()
        }
    }
    FileView {
        path: Quickshell.env("ORGM_WIDGET_CONFIG")
        watchChanges: true
        printErrors: false
        onFileChanged: root.reload()
    }
}
