pragma Singleton
import QtQuick
import Quickshell

// Adapted from shadowofdominance/swaydots; see ../NOTICE.md.
Singleton {
    property var palette: ({})
    readonly property color bg: palette.bg || "#080808"
    readonly property color surface: palette.surface || "#202020"
    readonly property color fg: palette.fg || "#f5f5f5"
    readonly property color muted: palette.muted || "#b8b8b8"
    readonly property color accent: palette.accent || "#8ab4f8"
    readonly property color error: palette.error || "#ff8a8a"
    readonly property color scrim: Qt.alpha(bg, 0.65)
    readonly property color panel: Qt.alpha(bg, 0.94)
    readonly property color outline: Qt.alpha(fg, 0.12)
    readonly property int radius: 22
    readonly property int radiusSmall: 12
    readonly property int spacing: 14
    readonly property int borderWidth: 2
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSmall: 12
    readonly property int fontNormal: 14
    readonly property int fontLarge: 18
    readonly property int animMed: 240
    readonly property int animSlow: 380
}
