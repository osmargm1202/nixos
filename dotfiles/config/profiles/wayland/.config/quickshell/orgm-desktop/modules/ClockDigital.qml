pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import "../lib/clock.js" as Clk

/**
 * Digital face: a big tabular mono time, the colon breathing once a second, with
 * the seconds and AM/PM stacked small to the right. The colon and seconds carry
 * the accent (palette, brand, or neutral by the Accent setting); the digits stay
 * bright ink so they read on any wallpaper.
 */
Item {
    id: face

    // the widget floats on the wallpaper, so its ink is picked against the patch
    // of picture under it. WidgetSlot measures it and pushes it in.
    property real underL: 50
    // a pinned colour ("" = follow wallpaper) paints this face's own ink.
    property string inkColorA: ""
    readonly property color ink:     Theme.inkOn2(face.underL, face.inkColorA)
    readonly property color inkDim:  Theme.inkDimOn2(face.underL, face.inkColorA)
    readonly property color inkSoft: Theme.inkSoftOn2(face.underL, face.inkColorA)

    readonly property var t: Clk.parts(Settings.now, Settings.clock24h)
    readonly property color accent: Clk.pickAccent(Settings.clockAccent, Theme.accentOn2(face.underL, face.inkColorA), Theme.brand, face.ink)
    readonly property real px: Math.round(88 * Settings.clockScale)
    readonly property bool side: Settings.clockSeconds || !Settings.clock24h

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: face.side ? Math.round(14 * Settings.clockScale) : 0

        Row {
            id: hm
            spacing: 0

            Text {
                text: face.t.hh
                color: face.ink
                font.family: Theme.mono
                font.pixelSize: face.px
                font.weight: Font.Bold
            }
            Text {
                text: ":"
                color: face.accent
                font.family: Theme.mono
                font.pixelSize: face.px
                font.weight: Font.Bold
            }
            Text {
                text: face.t.mm
                color: face.ink
                font.family: Theme.mono
                font.pixelSize: face.px
                font.weight: Font.Bold
            }
        }

        Item {
            height: hm.height
            width: Math.max(secs.implicitWidth, ampm.implicitWidth)
            visible: face.side

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(4 * Settings.clockScale)

                Text {
                    id: secs
                    visible: Settings.clockSeconds
                    text: face.t.ss
                    color: face.accent
                    font.family: Theme.mono
                    font.pixelSize: Math.round(face.px * 0.3)
                    font.weight: Font.DemiBold
                }
                Text {
                    id: ampm
                    visible: !Settings.clock24h
                    text: face.t.ampm
                    color: face.inkDim
                    font.family: Theme.mono
                    font.pixelSize: Math.round(face.px * 0.24)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }
            }
        }
    }
}
