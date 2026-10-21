// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Io
Scope {
 id:root
 readonly property string backend:Quickshell.env("ORGM_DESKTOP_COMPOSITOR")==="hyprland"?"hyprland":"sway"
 readonly property var palette:JSON.parse(Quickshell.env("ORGM_TABLET_PALETTE")||"{}")
 function command(action) {
  if(action==="launcher")return [backend==="sway"?"sway-app-launcher":"hypr-app-launcher"];
  if(action==="windows")return ["orgm-"+backend,"windows"];
  return ["orgm-osk","toggle"];
 }
 IpcHandler {
  target:"tablet-dock"
  function status():string {
   var items=[];
   for(var n=0;n<buttons.count;n++) {
    var item=buttons.itemAt(n);
    items.push({action:item.modelData.action,x:(dock.screen.width-dock.width)/2+background.x+strip.x+item.x,
     y:dock.screen.height-dock.height+background.y+strip.y+item.y,width:item.width,height:item.height});
   }
   return JSON.stringify({backend:root.backend,buttons:items});
  }
 }
 PanelWindow {
  id:dock
  screen:Quickshell.screens.find(s=>s.name===Quickshell.env("ORGM_TABLET_DOCK_OUTPUT"))||Quickshell.screens[0]
  anchors.bottom:true
  implicitWidth:272;implicitHeight:84;exclusiveZone:84
  focusable:false;aboveWindows:true;color:"transparent"
  Rectangle {
   id:background
   anchors { fill:parent; margins:6 }
   radius:14;color:root.palette.bg||"#080808"
   Row {
    id:strip
    anchors.centerIn:parent;spacing:4
    Repeater {
     id:buttons
     model:[{action:"launcher",label:"Apps",icon:"apps"},{action:"windows",label:"Ventanas",icon:"windows"},{action:"keyboard",label:"Teclado",icon:"keyboard"}]
     delegate:Rectangle {
      required property var modelData
      width:80;height:64;radius:10
      color:area.pressed?(root.palette.accent||"#8ab4f8"):(root.palette.surface||"#202020")
      Image { anchors.horizontalCenter:parent.horizontalCenter;y:5;width:28;height:28;source:"icons/"+modelData.icon+".svg" }
      Text { anchors.horizontalCenter:parent.horizontalCenter;y:40;text:modelData.label;font.pixelSize:13;color:root.palette.fg||"#f5f5f5" }
      Process { id:action;onExited:(code,status)=>{if(code!==0)console.warn("No se pudo abrir la acción tablet")}; }
      MouseArea { id:area;anchors.fill:parent;onClicked:{if(!action.running){action.command=root.command(modelData.action);action.running=true;}} }
     }
    }
   }
  }
 }
}
