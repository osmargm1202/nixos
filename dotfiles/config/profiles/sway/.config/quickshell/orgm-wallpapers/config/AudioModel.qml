pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var inputs: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    property PwObjectTracker tracker: PwObjectTracker { objects: Pipewire.nodes.values }
    function setDefault(node) {
        if (node.isSink) Pipewire.preferredDefaultAudioSink = node
        else Pipewire.preferredDefaultAudioSource = node
    }
    function volume(node, percent) { if (node && node.audio) node.audio.volume = Math.max(0, Math.min(150, percent)) / 100 }
    function mute(node) { if (node && node.audio) node.audio.muted = !node.audio.muted }
}
