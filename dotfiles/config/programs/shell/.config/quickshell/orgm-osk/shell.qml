// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
Scope {
 id:root
 property bool opened:false
 property string output:""
 property bool ready:false
 property string error:""
 property real keyScale:1
 property var panels:[]
 function show(name) { output=name||(Quickshell.screens[0]?Quickshell.screens[0].name:""); opened=true; }
 function hide() { opened=false; for (var panel of panels) panel.reset(); send({action:"release"}); }
 function retry() { if (!engine.running) { ready=false; error=""; engine.running=true; } }
 function overlay(panel) { if (panel.WlrLayershell != null) panel.WlrLayershell.layer=WlrLayer.Overlay; }
 function toggle(name) { if (opened) hide(); else show(name); }
 function send(value) { if (engine.running) engine.write(JSON.stringify(value)+"\n"); }
 Process {
  id:engine; command:[Quickshell.env("ORGM_OSK_ENGINE")||"orgm-osk-engine"]
  running:true; stdinEnabled:true
  stdout:SplitParser {
   onRead:data=>{
    try {
     var message=JSON.parse(data);
     if (message.event==="ready") { root.ready=true; root.error=""; }
     else if (message.event==="error") root.error="Error de teclado: "+message.error;
    } catch(e) { root.error="Respuesta inválida del teclado"; }
   }
  }
  onExited: { root.ready=false; if (!root.error) root.error="El servicio de entrada se detuvo"; }
 }
 IpcHandler {
  target:"osk"
  function show():void { root.show(""); }
  function hide():void { root.hide(); }
  function toggle():void { root.toggle(""); }
  function retry():void { root.retry(); }
  function status():string { return JSON.stringify({open:root.opened,ready:root.ready,error:root.error,panels:root.panels.map(p=>p.snapshot())}); }
 }
 Variants {
  model:Quickshell.screens
  delegate:Scope {
   id:surface; required property var modelData
   readonly property bool active:root.opened&&root.output===modelData.name
   function reset() { board.reset(); }
   function snapshot() {
    return {screen:modelData.name,
     button:{x:button.margins.left,y:modelData.height-button.margins.bottom-button.height,width:button.width,height:button.height},
     keyboard:{x:(modelData.width-background.width)/2+10,y:modelData.height-keyboard.height+10,width:board.width,height:board.height},keys:board.snapshot()};
   }
   Component.onCompleted:root.panels=[...root.panels,surface]
   Component.onDestruction:root.panels=root.panels.filter(p=>p!==surface)
   PanelWindow {
    id:keyboard; screen:surface.modelData; visible:surface.active
    anchors { bottom:true; left:true; right:true }
    implicitHeight:Math.min(screen.height*0.48,330*root.keyScale)
    exclusiveZone:visible?implicitHeight:0
    focusable:false; aboveWindows:true; color:"transparent"
    Component.onCompleted:root.overlay(this)
    mask:Region { item:background }
    Rectangle {
     id:background; anchors.horizontalCenter:parent.horizontalCenter
     width:Math.min(parent.width-20,1120*root.keyScale); height:parent.height; radius:14; color:"#24273a"
     Keyboard { id:board; anchors.fill:parent; anchors.margins:10; controller:root }
    }
   }
   PanelWindow {
    id:button; screen:surface.modelData
    anchors { bottom:true; left:true }
    implicitWidth:52; implicitHeight:48
    margins { left:16; bottom:surface.active?keyboard.height+12:18 }
    exclusionMode:ExclusionMode.Ignore; focusable:false; aboveWindows:true; color:"transparent"
    Component.onCompleted:root.overlay(this)
    Rectangle {
     anchors.fill:parent; radius:14; color:root.error?"#ed8796":"#8aadf4"
     Text { anchors.centerIn:parent; text:"⌨"; font.pixelSize:29; color:"#24273a" }
     MouseArea { anchors.fill:parent; onClicked:root.toggle(surface.modelData.name) }
    }
   }
   PanelWindow {
    screen:surface.modelData; visible:!surface.active
    anchors.bottom:true; implicitWidth:150; implicitHeight:14
    exclusionMode:ExclusionMode.Ignore; focusable:false; aboveWindows:true; color:"transparent"
    Component.onCompleted:root.overlay(this)
    Rectangle { anchors.centerIn:parent; width:60; height:5; radius:3; color:"#8aadf4" }
    MouseArea {
     anchors.fill:parent; property real startY:0; property bool armed:false
     onPressed:mouse=>{startY=mouse.y;armed=true;}
     onPositionChanged:mouse=>{if(armed&&mouse.y<startY-65){armed=false;root.show(surface.modelData.name);}}
     onReleased:armed=false
     onCanceled:armed=false
    }
   }
  }
 }
}
