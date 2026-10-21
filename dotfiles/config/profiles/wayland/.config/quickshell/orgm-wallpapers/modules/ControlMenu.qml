import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.config
import qs.components

MenuWindow {
 id:root
 layerNamespace:"orgm-control"
 property var catalog: ({})
 property var state:catalog.state || ({})
 property string errorText:""
 readonly property string choice:""
 readonly property bool confirming:false
 readonly property bool tablet:!!(state.tablet && state.tablet.active)
 readonly property var controls:state.controls || []
 readonly property var sections:[...new Set(controls.map(c=>c.section))]
 signal chosen(string value)
 function reset() { state=catalog.state || {};errorText="";scroller.contentItem.contentY=0; }
 screen:Quickshell.screens.find(s=>s.name===catalog.screen) || Quickshell.screens[0]
 function action(name,value) {
  if (update.running) return;
  update.command=[catalog.backend,"control-action",name,value===undefined?"":String(value)];update.running=true;
 }
 function selected(control) {
  if(control.id==="tablet")return tablet;
  if(control.id==="keyboard")return state.tablet && state.tablet.keyboardVisible;
  if(["gaming","dnd","caffeine"].includes(control.id))return state[control.id]===true;
  if(control.action==="workspace")return state.workspace===Number(control.value);
  return state.powerProfile===control.id;
 }
 function available(control) {
  if(control.id==="caffeine")return state.caffeineAvailable===true;
  if(control.id==="tablet")return state.tablet && state.tablet.available;
  if(control.id==="keyboard")return state.tablet && state.tablet.keyboardAvailable;
  if(control.action==="profile")return control.available && !!state.powerProfile;
  if(control.action==="media")return control.available && state.mediaAvailable===true;
  return control.available;
 }
 function snapshot() {
  var result=[];
  for(var i=0;i<groups.count;i++) {
   var section=groups.itemAt(i);
   for(var j=0;j<section.buttons.count;j++) {
    var b=section.buttons.itemAt(j),p=b.mapToItem(root.contentItem,0,0);
    result.push({id:b.modelData.id,x:p.x,y:p.y,width:b.width,height:b.height,enabled:b.enabled});
   }
  }
  return result;
 }
 Process {
  id:update
  stdout:StdioCollector { onStreamFinished: {
   try {root.state=JSON.parse(text);root.errorText="";}catch(error){root.errorText="No se pudo actualizar el control";}
  } }
  onExited:(code,status)=>{if(code!==0)root.errorText="No se pudo aplicar el cambio";}
 }
 Timer { interval:2500;repeat:true;running:root.open;onTriggered:if(!update.running){update.command=[root.catalog.backend,"control-state"];update.running=true;} }
 Timer { id:brightness;property int pending:50;interval:120;onTriggered:if(update.running)restart();else root.action("brightness",pending) }
 Surface {
  anchors.centerIn:parent;width:Math.min(root.tablet?760:660,root.width-32);height:Math.min(920,root.height-32)
  radius:Style.radius;opacity:root.progress
  ScrollView {
   id:scroller;anchors.fill:parent;anchors.margins:root.tablet?24:20;contentWidth:availableWidth;clip:true
   Column {
    width:scroller.availableWidth;spacing:16
    Text { text:"Centro de control";color:Style.fg;font.family:Style.font;font.pixelSize:26 }
    Text { width:parent.width;text:Qt.formatDateTime(new Date(),"dddd d MMMM · hh:mm")+"\n"+(root.state.battery || "")+" · "+(root.state.network || "");color:Style.muted;font.pixelSize:root.tablet?16:14;wrapMode:Text.Wrap;textFormat:Text.PlainText }
    MenuSlider { width:parent.width;label:root.state.brightness===null?"Brillo no disponible":"Brillo";minimum:5;enabled:root.state.brightness!==null && root.state.brightness!==undefined;level:root.state.brightness || 5;onAdjusted:percent=>{brightness.pending=Math.round(percent);brightness.restart();} }
    Repeater {
     model:[{label:"Volumen",node:AudioModel.sink},{label:"Micrófono",node:AudioModel.source}]
     delegate:Row {
      required property var modelData
      width:parent.width;spacing:12
      MenuSlider { width:parent.width-126;label:modelData.label+(modelData.node?"":" · sin dispositivo");maximum:150;enabled:modelData.node!==null;level:modelData.node && modelData.node.audio?modelData.node.audio.volume*100:0;onAdjusted:percent=>AudioModel.volume(modelData.node,percent) }
      MenuButton { width:114;height:root.tablet?60:48;text:modelData.node && modelData.node.audio && modelData.node.audio.muted?"Activar":"Silenciar";enabled:modelData.node!==null;onClicked:AudioModel.mute(modelData.node) }
     }
    }
    Text { visible:!!root.state.media;width:parent.width;text:root.state.media || "";textFormat:Text.PlainText;color:Style.muted;font.pixelSize:16;elide:Text.ElideRight }
    Repeater {
     id:groups;model:root.sections
     delegate:Column {
      id:section;required property string modelData;property alias buttons:entries
      width:parent.width;spacing:10
      Text { text:section.modelData;color:Style.accent;font.pixelSize:root.tablet?20:18;font.family:Style.font }
      Grid {
       width:parent.width;columns:section.modelData==="Espacios de trabajo"?5:(width<400?1:2);spacing:10
       Repeater {
        id:entries;model:root.controls.filter(c=>c.section===section.modelData)
        delegate:MenuButton {
         required property var modelData
         width:(parent.width-(parent.columns-1)*parent.spacing)/parent.columns;height:root.tablet?64:52
         text:modelData.label+(root.available(modelData)?"":" · no disponible");fontSize:root.tablet?17:14
         highlighted:root.selected(modelData);enabled:root.available(modelData) && !update.running
         onClicked:if(modelData.action)root.action(modelData.action,modelData.value);else root.chosen(modelData.id)
        }
       }
      }
     }
    }
    Text { text:"Bandeja de aplicaciones";color:Style.accent;font.pixelSize:20 }
    Text { visible:SystemTray.items.values.length===0;text:"No hay aplicaciones en la bandeja";color:Style.muted;font.pixelSize:14 }
    Flow {
     width:parent.width;spacing:10
     Repeater {
      model:SystemTray.items
      delegate:MenuButton {
       id:trayButton;required property var modelData;width:Math.min(200,parent.width);height:64
       text:modelData.title || modelData.tooltipTitle || modelData.id
       onClicked: {
        var p=trayButton.mapToItem(root.contentItem,0,trayButton.height);
        if(modelData.hasMenu)modelData.display(root,p.x,p.y);else modelData.activate();
       }
      }
     }
    }
    Text { width:parent.width;text:root.errorText || "Desliza para ver todas las opciones · Esc o clic fuera: cerrar";wrapMode:Text.Wrap;color:root.errorText?Style.error:Style.muted;font.pixelSize:14 }
   }
  }
 }
}
