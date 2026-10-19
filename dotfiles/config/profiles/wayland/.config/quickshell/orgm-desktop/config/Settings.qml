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
    function reload() { reader.running = true }
    FileView {
        path: Quickshell.env("ORGM_WIDGET_CONFIG")
        watchChanges: true
        printErrors: false
        onFileChanged: root.reload()
    }
}
