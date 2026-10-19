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
    signal adjusted(var node, real percent, bool muted)
    function setDefault(node) {
        if (node.isSink) Pipewire.preferredDefaultAudioSink = node
        else Pipewire.preferredDefaultAudioSource = node
    }
    function volume(node, percent) {
        if (!node || !node.audio) return
        const value = Math.max(0, Math.min(150, percent))
        node.audio.volume = value / 100
        adjusted(node, value, node.audio.muted)
    }
    function mute(node) {
        if (!node || !node.audio) return
        const muted = !node.audio.muted
        node.audio.muted = muted
        adjusted(node, node.audio.volume * 100, muted)
    }
    function adjust(target, action) {
        if (!["output", "input"].includes(target) || !["up", "down", "mute"].includes(action)) return false
        const node = target === "input" ? source : sink
        if (!node || !node.audio) return false
        if (action === "mute") mute(node)
        else volume(node, Math.round(node.audio.volume * 100) + (action === "up" ? 3 : -3))
        return true
    }
}
