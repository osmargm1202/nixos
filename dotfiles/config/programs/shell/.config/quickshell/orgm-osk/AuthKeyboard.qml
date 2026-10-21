// SPDX-License-Identifier: GPL-3.0-or-later
// Local Qt editor only. No global input engine, process, credential IPC or auth API.
import QtQuick
import QtQuick.Window
Item {
 id: auth
 property bool open: false
 property real keyScale: 1
 property var editor: null
 property string pendingAccent: ""
 readonly property var localWindow: Window.window
 readonly property bool ready: !!(editor && localWindow && localWindow.active &&
   editor.Window.window === localWindow && editor.visible && editor.enabled && !editor.readOnly)
 readonly property string error: ready ? "" : "Toca el campo de contraseña"
 readonly property real reservedHeight: open ? boardFrame.height + 20 : 0
 property alias board: keys
 property alias button: toggle
 function editable(item) {
  return item && item.Window.window === localWindow && typeof item.insert === "function" &&
    typeof item.remove === "function" && typeof item.cursorPosition === "number" && !item.readOnly;
 }
 function capture() {
  var next=localWindow ? localWindow.activeFocusItem : null;
  if (editable(next) && next !== editor) { editor=next; pendingAccent=""; }
 }
 function retry() { capture(); }
 function hide() { open=false; pendingAccent=""; keys.reset(); }
 function replaceSelection(text) {
  var start=editor.selectionStart, end=editor.selectionEnd;
  if (end>start) editor.remove(start,end);
  editor.insert(editor.cursorPosition,text);
 }
 function send(key) {
  if (!ready || (key.modifiers & 12)) return;
  editor.forceActiveFocus();
  if (key.code === 1) { hide(); return; }
  if (key.code === 28) {
   pendingAccent="";
   // Invoke the original field's normal submit signal, never authenticate here.
   if (typeof editor.accepted === "function") editor.accepted();
   return;
  }
  if (key.code === 15) {
   var next=editor.nextItemInFocusChain(true);
   if (next) next.forceActiveFocus(Qt.TabFocusReason);
   return;
  }
  if (key.code === 14 || key.code === 111) {
   if (pendingAccent) { pendingAccent=""; return; }
   var a=editor.selectionStart,b=editor.selectionEnd,p=editor.cursorPosition;
   if (b>a) editor.remove(a,b);
   else if (key.code===14 && p>0) {
    var prev=editor.getText(Math.max(0,p-2),p);
    editor.remove(p-(prev.length===2 && /[\uD800-\uDBFF][\uDC00-\uDFFF]/.test(prev)?2:1),p);
   } else if (key.code===111) {
    var after=editor.getText(p,p+2);
    if (after.length) editor.remove(p,p+(/[\uD800-\uDBFF][\uDC00-\uDFFF]/.test(after)?2:1));
   }
   return;
  }
  if ([103,105,106,108].includes(key.code)) {
   pendingAccent="";
   if (key.code===105) editor.cursorPosition=Math.max(0,editor.cursorPosition-1);
   else if (key.code===106) editor.cursorPosition=editor.cursorPosition+1;
   return;
  }
  if (key.dead) {
   if (pendingAccent) replaceSelection(pendingAccent);
   pendingAccent=key.dead==="dead_acute"?"´":"¨";
   return;
  }
  if (!key.text) return;
  var value=key.text;
  if (pendingAccent) {
   var accent=pendingAccent;pendingAccent="";
   value=value===" "?accent:(value+(accent==="´"?"\u0301":"\u0308")).normalize("NFC");
  }
  replaceSelection(value);
 }
 Connections {
  target: auth.localWindow
  function onActiveFocusItemChanged() { auth.capture(); }
 }
 Rectangle {
  id: toggle
  x:16; y:parent.height-height-12-(auth.open?boardFrame.height+14:0)
  width:156; height:52; radius:12; color:mouse.pressed?"#8aadf4":"#363a4f"
  Text { anchors.centerIn:parent; text:auth.open?"Ocultar teclado":"⌨  Teclado"; color:"#cad3f5"; font.pixelSize:17 }
  MouseArea { id:mouse; anchors.fill:parent; onClicked: { auth.capture(); auth.open=!auth.open; if (!auth.open) auth.hide(); } }
 }
 Rectangle {
  id:boardFrame
  anchors.horizontalCenter:parent.horizontalCenter; anchors.bottom:parent.bottom; anchors.bottomMargin:10
  width:Math.min(parent.width-24,1100); height:Math.min(parent.height*0.48,360*auth.keyScale)
  color:"#24273a"; radius:14; visible:auth.open
  Keyboard { id:keys; anchors.fill:parent; anchors.margins:10; controller:auth; allowShortcuts:false }
 }
 Component.onCompleted: Qt.callLater(capture)
}
