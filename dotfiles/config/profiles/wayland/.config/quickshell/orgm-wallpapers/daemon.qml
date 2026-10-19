import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules

// One session process preloads the desktop menus; only one panel takes focus.
ShellRoot {
    id: root
    readonly property string backend: Quickshell.env("ORGM_SWAY_DESKTOP_BACKEND")
    readonly property var panels: ({ windows, control, audio, clipboard, profiles, power, wallpaper })
    property var current: null
    property var pending: null
    property string lastKind: "windows"
    FileView { id: data; blockLoading: true; printErrors: false }
    FileView { id: result; blockWrites: true; printErrors: false }
    FileView { id: completion; blockWrites: true; printErrors: false }
    FileView {
        id: palette
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + (Style.hyprlandSession ? "/waybar-hypr/orgm-current.css" : "/waybar/orgm-current.css")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const definitions = {}
            const pattern = /@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6})\s*;/g
            let match
            while ((match = pattern.exec(text())) !== null) definitions[match[1]] = match[2]
            const colors = {}
            const mapping = { bg: "base", surface: "surface0", fg: "text", muted: "overlay0", accent: "blue", error: "red" }
            for (const key of Object.keys(mapping)) if (definitions[mapping[key]]) colors[key] = definitions[mapping[key]]
            Style.palette = colors
        }
    }
    AudioOsd { id: audioOsd }
    Connections {
        target: AudioModel
        function onAdjusted(node, percent, muted) { audioOsd.present(node, percent, muted) }
    }
    IpcHandler {
        target: "osd"
        function adjust(target: string, action: string): string { return AudioModel.adjust(target, action) ? "ok" : "unavailable" }
        function display(target: string, percent: int, muted: bool): void {
            if (!["output", "input"].includes(target)) return
            audioOsd.present(target === "input" ? AudioModel.source : AudioModel.sink, percent, muted, target)
        }
        function status(): string { return JSON.stringify(audioOsd.snapshot()) }
        function hide(): void { audioOsd.active = false }
    }

    function complete(request) {
        if (!request) return
        if (request.resultPath) {
            result.path = request.resultPath
            result.setText((request.selection || "") + "\n")
            result.path = ""
        }
        if (request.donePath) {
            completion.path = request.donePath
            completion.setText("done")
            completion.path = ""
        }
    }
    function present(request) {
        current = request
        lastKind = request.catalog.kind
        Style.palette = request.catalog.colors || {}
        const panel = panels[lastKind]
        panel.catalog = request.catalog
        panel.show()
    }
    function enqueue(request) {
        const kind = request.catalog.kind
        if (!panels[kind]) return "invalid"
        if (current && panels[current.catalog.kind].busy) return "busy"
        if (pending && pending.catalog.kind === "windows" && kind === "windows") {
            pending.catalog.direction += request.catalog.direction
            return "duplicate"
        }
        if (current && current.catalog.kind === kind && panels[kind].open) {
            if (kind === "windows") panels.windows.move(request.catalog.direction < 0 ? -1 : 1)
            return "duplicate"
        }
        if (current) {
            complete(pending)
            pending = request
            panels[current.catalog.kind].close()
        } else present(request)
        return "accepted:" + Quickshell.processId
    }
    function dismissed(kind) {
        if (!current || current.catalog.kind !== kind) return
        const finished = current
        current = null
        // Drop history and image catalogs before clients remove their private files.
        if (kind !== "windows") { panels[kind].catalog = ({}); panels[kind].reset() }
        complete(finished)
        if (pending) {
            const next = pending
            pending = null
            present(next)
        }
    }
    function choose(kind, value) {
        if (!current || current.catalog.kind !== kind) return
        current.selection = value
        panels[kind].close()
        if (kind === "windows") Quickshell.execDetached([backend, "windows-focus", value])
    }

    WindowSwitcher { id: windows; onChosen: value => root.choose("windows", value); onDismissed: root.dismissed("windows") }
    ControlMenu { id: control; onChosen: value => root.choose("control", value); onDismissed: root.dismissed("control") }
    AudioMenu { id: audio; onChosen: value => root.choose("audio", value); onDismissed: root.dismissed("audio") }
    ClipboardMenu { id: clipboard; onChosen: value => root.choose("clipboard", value); onDismissed: root.dismissed("clipboard") }
    ProfilePicker { id: profiles; onChosen: value => root.choose("profiles", value); onDismissed: root.dismissed("profiles") }
    PowerMenu { id: power; onChosen: value => root.choose("power", value); onDismissed: root.dismissed("power") }
    WallpaperPicker { id: wallpaper; onDismissed: root.dismissed("wallpaper") }

    IpcHandler {
        target: "menu"
        function open(payload: string): void { root.enqueue({ catalog: JSON.parse(payload) }) }
        function request(catalogPath: string, resultPath: string, donePath: string): string {
            try {
                data.path = catalogPath
                const catalog = JSON.parse(data.text())
                data.path = ""
                return root.enqueue({ catalog, resultPath, donePath })
            } catch (error) { console.error("No se pudo abrir el menú: " + error); return "invalid" }
        }
        function status(): string {
            const kind = root.current ? root.current.catalog.kind : root.lastKind
            const panel = root.panels[kind]
            return JSON.stringify({ kind, pid: Quickshell.processId, preloaded: Object.keys(root.panels),
                open: panel.open, visible: panel.visible, confirming: panel.confirming || false,
                choice: panel.choice || "", screen: panel.screen ? panel.screen.name : "",
                items: panel.catalog.items || [], colors: panel.catalog.colors || {},
                state: kind === "control" ? panel.state : null,
                overview: kind === "windows" ? panel.snapshot() : null,
                audio: kind === "audio" ? panel.snapshot() : null })
        }
        function advance(direction: int): void { if (windows.open) windows.move(direction) }
        function owns(donePath: string): string {
            return (root.current && root.current.donePath === donePath)
                || (root.pending && root.pending.donePath === donePath) ? "yes" : "no"
        }
        function close(): void { if (root.current) root.panels[root.current.catalog.kind].close() }
    }
}
