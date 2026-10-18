import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules

// Only this picker is instantiated. No power/network menus or resident shell.
ShellRoot {
    ThemePicker {
        id: picker
        onDismissed: Qt.quit()
    }
    FileView {
        id: data
        path: Quickshell.env("ORGM_WALLPAPER_DATA")
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: startup
        path: Quickshell.env("ORGM_WALLPAPER_STATUS")
        blockWrites: true
        printErrors: false
    }
    Component.onCompleted: {
        try {
            picker.catalog = JSON.parse(data.text())
            if (!Array.isArray(picker.catalog.items)) throw new Error("Catálogo sin imágenes")
            Style.palette = picker.catalog.colors || {}
            picker.syncToSaved()
            picker.show()
            if (startup.path) startup.setText("ready")
        } catch (error) {
            console.error("No se pudo leer el catálogo de fondos: " + error)
            if (startup.path) startup.setText("error")
            // Engine quit handlers are installed after initial component creation.
            Qt.callLater(Qt.quit)
        }
    }
}
