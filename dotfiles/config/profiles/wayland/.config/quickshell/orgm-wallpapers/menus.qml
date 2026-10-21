import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules

// On-demand menus share the wallpaper picker's components and active palette.
ShellRoot {
    id: root
    property var catalog: ({})
    FileView { id: data; path: Quickshell.env("ORGM_WALLPAPER_DATA"); blockLoading: true; printErrors: false }
    FileView { id: startup; path: Quickshell.env("ORGM_WALLPAPER_STATUS"); blockWrites: true; printErrors: false }
    FileView { id: result; path: Quickshell.env("ORGM_MENU_RESULT"); blockWrites: true; printErrors: false }
    Component { id: power; PowerMenu {} }
    Component { id: profiles; ProfilePicker {} }
    Component { id: control; ControlMenu {} }
    Component { id: audio; AudioMenu {} }
    Component { id: windows; WindowSwitcher {} }
    Component { id: clipboard; ClipboardMenu {} }
    Loader {
        id: menu
        active: false
        sourceComponent: ({ power, profiles, control, audio, windows, clipboard })[root.catalog.kind] || power
        onLoaded: {
            item.catalog = root.catalog
            item.dismissed.connect(Qt.quit)
            item.chosen.connect(value => {
                result.setText(value + "\n")
                menu.item.close()
            })
            item.show()
            if (startup.path) startup.setText("ready")
        }
    }
    IpcHandler {
        target: "menu"
        function status(): string {
            return JSON.stringify({ kind: root.catalog.kind,
                choice: menu.item ? menu.item.choice : "",
                confirming: menu.item ? menu.item.confirming : false,
                screen: menu.item && menu.item.screen ? menu.item.screen.name : "",
                items: root.catalog.items || [], colors: root.catalog.colors || {},
                state: root.catalog.kind === "control" && menu.item ? menu.item.state : null,
                controls: root.catalog.kind === "control" && menu.item ? menu.item.snapshot() : null,
                overview: root.catalog.kind === "windows" && menu.item ? menu.item.snapshot() : null,
                audio: root.catalog.kind === "audio" && menu.item ? menu.item.snapshot() : null })
        }
        function advance(direction: int): void { if (root.catalog.kind === "windows" && menu.item) menu.item.move(direction) }
        function close(): void { if (menu.item) menu.item.close() }
    }
    Component.onCompleted: {
        try {
            root.catalog = JSON.parse(data.text())
            if (!["power", "profiles", "control", "audio", "windows", "clipboard"].includes(root.catalog.kind)) throw new Error("Menú desconocido")
            Style.palette = root.catalog.colors || {}
            menu.active = true
        } catch (error) {
            console.error("No se pudo abrir el menú: " + error)
            if (startup.path) startup.setText("error")
            Qt.callLater(Qt.quit)
        }
    }
}
