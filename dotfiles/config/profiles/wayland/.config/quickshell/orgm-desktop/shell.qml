import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.config
import qs.modules

ShellRoot {
    id: root
    property var slots: []
    property bool editing: false
    function snapshot() { return JSON.stringify({ design: "digital", editing, saving: Settings.saving, error: Settings.errorText, date: Qt.formatDateTime(Settings.now, "yyyy-MM-dd"), screens: slots.map(s => s.snapshot()) }) }
    IpcHandler {
        target: "widgets"
        function status(): string { return root.snapshot() }
        function reload(): void { Settings.reload() }
        function edit(): void { root.editing = !root.editing }
        function done(): void { root.editing = false }
        function shiftMonth(delta: int): void { for (const slot of root.slots) if (slot.widget === "calendar") slot.widgetItem.shift(delta) }
    }
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: monitor
            required property var modelData
            WidgetWindow { screen: monitor.modelData; widget: "clock"; enabled: Settings.values.clockEnabled !== false }
            WidgetWindow { screen: monitor.modelData; widget: "calendar"; enabled: Settings.values.calendarEnabled !== false }
            WidgetEditor {
                screen: monitor.modelData
                visible: root.editing
                slots: root.slots.filter(s => s.screen && s.screen.name === monitor.modelData.name)
                onDone: root.editing = false
            }
        }
    }
    component WidgetWindow: PanelWindow {
        id: win
        property string widget
        property bool enabled: true
        readonly property var widgetItem: loader.item
        readonly property real naturalWidth: loader.implicitWidth
        readonly property real naturalHeight: loader.implicitHeight
        readonly property var peers: root.slots.filter(s => s.screen && screen && s.screen.name === screen.name && s.enabled)
        readonly property var clockPeer: peers.find(s => s.widget === "clock")
        readonly property var calendarPeer: peers.find(s => s.widget === "calendar")
        readonly property var placement: Settings.placement(widget, screen ? screen.name : "")
        readonly property real fit: Math.max(.05, Math.min(1,
            (screen.width - 16) / Math.max(1, ...peers.map(s => s.naturalWidth)),
            (screen.height - 24) / Math.max(1, peers.reduce((height, s) => height + s.naturalHeight, 0))))
        visible: enabled && !root.editing
        color: "transparent"
        anchors { left: true; top: true }
        implicitWidth: Math.max(1, Math.ceil(loader.implicitWidth * fit))
        implicitHeight: Math.max(1, Math.ceil(loader.implicitHeight * fit))
        margins.left: Math.min(placement.x, Math.max(0, screen.width - implicitWidth - 8))
        margins.top: placement.free ? Math.min(placement.y, Math.max(0, screen.height - implicitHeight - 8))
            : widget === "clock"
            ? Math.min(Settings.values.clockY || 0, Math.max(8, screen.height - implicitHeight - (calendarPeer && !calendarPeer.placement.free ? calendarPeer.implicitHeight + 16 : 8)))
            : Math.max(clockPeer && !clockPeer.placement.free ? clockPeer.margins.top + clockPeer.implicitHeight + 8 : 0,
                Math.min(Settings.values.calendarY || 0, Math.max(0, screen.height - implicitHeight - 8)))
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "orgm-desktop-" + widget
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        function snapshot() { return { widget, screen: screen.name, visible: enabled, x: margins.left, y: margins.top, width: implicitWidth, height: implicitHeight } }
        Loader {
            id: loader
            scale: win.fit
            transformOrigin: Item.TopLeft
            sourceComponent: win.widget === "clock" ? clockComponent : calendarComponent
        }
        Component { id: clockComponent; DesktopClock {} }
        Component { id: calendarComponent; DesktopCalendar {} }
        Component.onCompleted: root.slots = [...root.slots, win]
        Component.onDestruction: root.slots = root.slots.filter(s => s !== win)
    }
}
