pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var palette: ({})
    readonly property color ink: palette.text || "#cad3f5"
    readonly property color inkDim: palette.subtext0 || "#a5adcb"
    readonly property color inkSoft: inkDim
    readonly property color faint: palette.overlay1 || "#8087a2"
    readonly property color accent: palette.blue || "#8aadf4"
    readonly property color brand: accent
    readonly property color surface: palette.base || "#24273a"
    readonly property color tileHover: palette.surface0 || "#363a4f"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property string font: "Sans"
    readonly property real radiusTile: 8
    readonly property int quick: 120
    readonly property int ease: Easing.OutCubic
    function inkOn2(l, c) { return c || ink }
    function inkDimOn2(l, c) { return c || inkDim }
    function inkSoftOn2(l, c) { return c || inkSoft }
    function accentOn2(l, c) { return c || accent }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
            + (Quickshell.env("XDG_CURRENT_DESKTOP").toLowerCase().includes("hyprland")
                ? "/waybar-hypr/orgm-current.css" : "/waybar/orgm-current.css")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const colors = {}
            const pattern = /@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6})\s*;/g
            let match
            while ((match = pattern.exec(text())) !== null) colors[match[1]] = match[2]
            root.palette = colors
        }
    }
}
