import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
  id: root

  property string home: Quickshell.env("HOME") || ""

  property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
  property string themePath: configHome + "/quickshell/theme/current.json"
  property var theme: ({ overlay: "#e611111b", border: "#33494d64", text: "#cad3f5", subtext: "#a5adcb", muted: "#6e738d", accent: "#8aadf4", success: "#a6da95", warning: "#eed49f", error: "#ed8796", pink: "#f5bde6", button: "#22363a4f", buttonStrong: "#33494d64", buttonSoft: "#1e363a4f", eventCard: "#2b363a4f", hover: "#55363a4f", outline: "#494d64", onAccent: "#11111b", disabled: "#363a4f" })

  FileView {
    id: themeFile
    path: root.themePath
    blockLoading: true
    watchChanges: true
    onFileChanged: themeReloadTimer.restart()
  }

  Timer { id: themeReloadTimer; interval: 60; repeat: false; onTriggered: root.loadTheme() }

  function loadTheme() {
    try {
      themeFile.reload()
      const text = themeFile.text()
      if (text && text.length > 0)
        root.theme = Object.assign({}, root.theme, JSON.parse(text))
    } catch (error) {
      console.log("theme load failed: " + error)
    }
  }
  property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
  property string cachePath: Quickshell.env("ORGM_HELPER_CACHE") || (stateHome + "/orgm-helper/keybindings.json")
  property string requestPath: Quickshell.env("ORGM_HELPER_REQUEST") || (stateHome + "/orgm-helper/keyhelper-request.json")
  property real scaleFactor: root.parseScale(Quickshell.env("HELPER_SCALE") || "1.00")
  property bool panelVisible: (Quickshell.env("ORGM_HELPER_SHOW") || "") === "1"
  property var data: ({ schemaVersion: 1, defaultCategory: "launchers", categories: [] })
  property string activeCategory: "launchers"
  property string errorText: ""
  property string lastRequestId: ""

  FileView {
    id: cacheFile
    path: root.cachePath
    blockLoading: true
    watchChanges: true
    onFileChanged: cacheReloadTimer.restart()
  }

  FileView {
    id: requestFile
    path: root.requestPath
    blockLoading: true
    watchChanges: true
    onFileChanged: requestReloadTimer.restart()
  }

  Timer { id: cacheReloadTimer; interval: 50; repeat: false; onTriggered: root.loadCache() }
  Timer { id: requestReloadTimer; interval: 40; repeat: false; onTriggered: root.loadRequest() }
  Timer { id: closeTimer; interval: 130; repeat: false; onTriggered: root.panelVisible = false }

  Component.onCompleted: {
    root.loadTheme()
    root.loadCache()
    if (root.panelVisible)
      root.showPanel()
  }

  function parseScale(value) {
    const parsed = Number(value)
    if (!isFinite(parsed) || parsed <= 0)
      return 1.0
    return Math.max(0.75, Math.min(1.75, parsed))
  }

  function unit(value) {
    return Math.round(value * root.scaleFactor)
  }

  function categories() {
    return root.data.categories || []
  }

  function activeEntries() {
    for (const cat of root.categories()) {
      if (cat.id === root.activeCategory)
        return cat.entries || []
    }
    return []
  }

  function activeCategoryTitle() {
    for (const cat of root.categories()) {
      if (cat.id === root.activeCategory)
        return (cat.icon || "") + " " + cat.title
    }
    return "Atajos"
  }

  function loadCache() {
    try {
      cacheFile.path = root.cachePath
      cacheFile.reload()
      const text = cacheFile.text()
      if (!text || text.length === 0) {
        root.errorText = "No helper cache found. Right-click ? to refresh."
        return
      }
      const parsed = JSON.parse(text)
      parsed.categories = parsed.categories || []
      root.data = parsed
      root.activeCategory = parsed.defaultCategory || (parsed.categories[0] ? parsed.categories[0].id : "")
      root.errorText = ""
    } catch (error) {
      root.errorText = "Could not read helper cache: " + error
    }
  }

  function loadRequest() {
    try {
      requestFile.path = root.requestPath
      requestFile.reload()
      const text = requestFile.text()
      const request = text && text.length > 0 ? JSON.parse(text) : ({ action: "toggle" })
      const id = String(request.id || request.nonce || request.timestamp || request.requestedAt || text)
      if (id === root.lastRequestId)
        return
      root.lastRequestId = id
      if (request.cachePath && request.cachePath.length > 0)
        root.cachePath = request.cachePath
      if (request.action === "show" || request.action === "open")
        root.showPanel()
      else if (request.action === "hide")
        root.hidePanel()
      else
        root.panelVisible ? root.hidePanel() : root.showPanel()
      root.loadCache()
    } catch (error) {
      root.panelVisible ? root.hidePanel() : root.showPanel()
    }
  }

  function showPanel() {
    root.panelVisible = true
    overlay.opacity = 1
    overlay.scale = 1
    overlay.forceActiveFocus()
  }

  function hidePanel() {
    overlay.opacity = 0
    overlay.scale = 0.96
    closeTimer.start()
  }

  PanelWindow {
    color: "transparent"
    visible: root.panelVisible
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "orgm-keyhelper"

    Rectangle {
      id: overlay
      width: root.unit(980)
      height: root.unit(620)
      radius: root.unit(22)
      color: root.theme.overlay
      border.color: root.theme.buttonStrong
      border.width: 1
      anchors.centerIn: parent
      opacity: 0
      scale: 0.96
      focus: true

      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
          root.hidePanel()
          event.accepted = true
        }
      }

      Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

      Column {
        anchors.fill: parent
        anchors.margins: root.unit(24)
        spacing: root.unit(16)

        Row {
          width: parent.width
          height: root.unit(34)
          spacing: root.unit(12)

          Text {
            text: "Atajos Hyprland"
            color: root.theme.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: root.unit(24)
            font.bold: true
            width: root.unit(260)
            elide: Text.ElideRight
          }

          Item { width: Math.max(0, parent.width - root.unit(260) - helper.width - root.unit(12)); height: 1 }

          Text {
            id: helper
            text: "Win+/ · Esc cierra"
            color: root.theme.subtext
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: root.unit(13)
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Text {
          visible: root.errorText.length > 0
          text: root.errorText
          color: root.theme.error
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: root.unit(15)
          wrapMode: Text.WordWrap
          width: parent.width
        }

        Row {
          visible: root.errorText.length === 0
          spacing: root.unit(18)
          width: parent.width
          height: root.unit(520)

          Rectangle {
            width: root.unit(210)
            height: parent.height
            radius: root.unit(14)
            color: root.theme.buttonSoft
            border.color: root.theme.outline

            Column {
              anchors.fill: parent
              anchors.margins: root.unit(10)
              spacing: root.unit(8)

              Repeater {
                model: root.categories()

                delegate: Rectangle {
                  width: parent.width
                  height: root.unit(42)
                  radius: root.unit(10)
                  color: modelData.id === root.activeCategory ? root.theme.outline : "transparent"

                  Text {
                    anchors.fill: parent
                    anchors.leftMargin: root.unit(12)
                    anchors.rightMargin: root.unit(12)
                    verticalAlignment: Text.AlignVCenter
                    text: (modelData.icon || "") + "  " + modelData.title
                    color: root.theme.text
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: root.unit(14)
                    elide: Text.ElideRight
                  }

                  MouseArea { anchors.fill: parent; onClicked: root.activeCategory = modelData.id }
                }
              }
            }
          }

          Column {
            width: parent.width - root.unit(228)
            height: parent.height
            spacing: root.unit(10)

            Text {
              text: root.activeCategoryTitle()
              color: root.theme.accent
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: root.unit(18)
              font.bold: true
              width: parent.width
              elide: Text.ElideRight
            }

            Repeater {
              model: root.activeEntries()

              delegate: Rectangle {
                width: parent.width
                height: root.unit(54)
                radius: root.unit(12)
                color: root.theme.eventCard
                border.color: root.theme.outline

                Text {
                  x: root.unit(16)
                  width: parent.width - shortcut.width - root.unit(48)
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.description
                  color: root.theme.text
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: root.unit(15)
                  elide: Text.ElideRight
                }

                Text {
                  id: shortcut
                  anchors.right: parent.right
                  anchors.rightMargin: root.unit(16)
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.key
                  color: root.theme.accent
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: root.unit(14)
                  font.bold: true
                }
              }
            }
          }
        }
      }
    }
  }
}
