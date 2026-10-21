# Teclado en pantalla para Envy / Quickshell — investigación 2026-10-20

## Goal

Buscar una implementación existente de teclado en Quickshell para adaptar y
desplegar nosotros; el usuario informa que el teclado de Envy apareció en una
prueba pero no en Rofi. Quiere poder abrirlo deliberadamente mediante gesto
u opción fija, no depender solo de detección automática.

## Instructions

- Esta fase es investigación, no autorización de un diseño final ni instalación.
- Conservar el escritorio existente; no instalar otra shell completa.
- No afirmar compatibilidad Rofi a partir de que el teclado se dibuje.
- Host local es orgm, no Envy: no se inspeccionó ni se cambió el runtime remoto.

## Discoveries

### Candidato principal: end-4 / illogical-impulse

Fuentes primarias:
- https://github.com/end-4/dots-hyprland
- https://raw.githubusercontent.com/end-4/dots-hyprland/main/dots/.config/quickshell/ii/modules/ii/onScreenKeyboard/OnScreenKeyboard.qml
- https://raw.githubusercontent.com/end-4/dots-hyprland/main/dots/.config/quickshell/ii/modules/ii/onScreenKeyboard/OskContent.qml
- https://raw.githubusercontent.com/end-4/dots-hyprland/main/dots/.config/quickshell/ii/modules/ii/onScreenKeyboard/OskKey.qml
- https://raw.githubusercontent.com/end-4/dots-hyprland/main/dots/.config/quickshell/ii/modules/ii/onScreenKeyboard/layouts.js
- https://raw.githubusercontent.com/end-4/dots-hyprland/main/dots/.config/quickshell/ii/services/Ydotool.qml
- https://github.com/end-4/dots-hyprland/blob/main/LICENSE

Referencia API inspeccionada: commit `2f2a376fdb2ad738bf55f693dd0b474b64bb0ab8`.
Licencia del repo GPL-3.0: preservar licencia/atribuciones y revisar cabeceras
al extraer módulos. No vendorizado ni ejecutado en esta investigación.

Es teclado real QML/Quickshell: filas/layouts, modificadores, tecla de cierre,
modo fijado, IPC osk open/close/toggle y shortcuts. Usa Ydotool para eventos
press/release, no solo para escribir en un TextInput local. Requiere desacoplar
Config/Appearance/GlobalStates/GlobalFocusGrab/servicios y llamadas Hyprland.
Su comentario de foco remite a Hyprland0.49: no copiar ciegamente esa política
en Sway/Hyprland actuales. Ydotool requiere revisar permisos/backend; valorar
un helper persistente del protocolo virtual-keyboard-v1 para evitar dar acceso
amplio a uinput. Eso sería una adaptación nueva, no una función ya probada aquí.

### DMS / Dux Common: no reemplazo global directo

El antiguo AvengeMedia/dank-qml-common redirige hoy a duxlabs-dev/dux-qml-common;
la carpeta actual es DCommon/Session, no DankCommon/Session. MIT.
- https://github.com/duxlabs-dev/dux-qml-common
- https://raw.githubusercontent.com/duxlabs-dev/dux-qml-common/master/DCommon/Session/Keyboard.qml
- https://raw.githubusercontent.com/duxlabs-dev/dux-qml-common/master/DCommon/Session/KeyboardController.qml

El componente recibe `property Item target`; sus acciones llaman
`target.insertText()`, `backspace()` y `accepted()`. Sirve para campos del
lock/greeter dentro de esa shell, pero no inyecta en Rofi ni otras apps por sí
solo. Puede ser referencia visual o de teclado interno de lock, no prometerlo
como OSK del escritorio sin añadir backend.

### Gestos ya explorados por otros

- https://github.com/short-circuit/qml-widgets
- https://raw.githubusercontent.com/short-circuit/qml-widgets/master/shell.qml

Franja inferior de25px, swipeup80px, PanelWindow overlay sin foco, llama
`qs -c ii ipc call osk toggle`: controla el teclado de end-4, no implementa
otro teclado. Repo pequeño (19commits, último push consultado2026-05-31).
La API no declara licencia y no aparece LICENSE en el árbol: no copiar su
código sin aclaración; usar como referencia de interacción o implementar propio.
Revisar conflicto con dock/barra táctil al reservar/capturar borde inferior.

### Alternativas / descartes

- Noctalia legacy OSK Toggle es controlador para Squeekboard/wvkbd, no teclado
  QML nuevo. La documentación oficial actual llama legacy-v4 a su antigua shell
  Quickshell; no migrar todo Noctalia para obtener un botón.
  https://docs.noctalia.dev/
- snry-shell deriva un OSK QML similar con foco None y backend/inputmethod.
  Inspección real: watcher.go detecta activate/deactivate de input-method-v2;
  el frontend todavía usa Ydotool. El README no demuestra que esa pieza inyecte
  todas las teclas por virtual-keyboard-v1. No instalar su daemon/sync global.
  https://github.com/sonroyaalmerol/snry-shell
- Alternativa pragmática: wvkbd existente + control propio Quickshell (botón/
  gesto). README actual soporta layouts personalizados y señales: USR1 hide,
  USR2 show, RTMIN toggle. v0.20 añade --auto sujeto a input-method-v2; el pin
  NixOS instalado debe verificarse, no asumir que trae auto por el README main.
  https://github.com/jjsullivan5196/wvkbd
  https://github.com/jjsullivan5196/wvkbd/releases

## Rofi: qué sabemos y qué no

No se pudo diagnosticar el teclado real de Envy desde esta sesión local.
En el árbol canónico inspeccionado no se encontró una declaración OSK actual;
puede ser runtime o trabajo externo. No inventar si usa Squeekboard/wvkbd/Qt.

Squeekboard documenta autoaparición cuando una aplicación compatible solicita
input-method; hay además show/hide manual por DBus. Eso hace plausible una
limitación de activación automática, pero **no prueba la causa en Envy**.
https://github.com/droidian/squeekboard/blob/upstream/README.md

También hay incidencias de capas con foco exclusivo que capturan el toque y
cierran menús en lugar de entregar pulsaciones al teclado. Es una posibilidad
para comprobar, no diagnóstico de nuestro Rofi. Cambiar solo de UI no garantiza
solucionarlo. Referencia de otro proyecto:
https://github.com/omacom/omarchy/issues/9029

## Accomplished

Investigación web y revisión de código fuente/árboles/licencias, sin ejecutar
código externo, instalar dependencias, modificar el teclado ni iniciar servicios.
Hallazgo accionable: existe base Quickshell end-4; no hay que construir el diseño
de teclas desde cero. DMS no resuelve la inyección a otras apps por sí solo.

## Next Steps

Propuesta aún no aprobada: extraer/adaptar solo OSK de end-4 como módulo propio,
botón Quickshell siempre accesible y gesto inferior opcional; no depender del
auto-show para poder abrirlo. Mantener foco del cliente; ocultar durante lock,
con teclado del lock como componente propio separado si luego se solicita.

Antes de sustituir el actual: identificar en Envy compositor/OSK/protocolos y
reproducir Rofi con toque real. Pruebas de aceptación: abrir teclado mientras
Rofi permanece abierto, escribir/filtro en Rofi, ñ/tildes/Shift/AltGr, Space,
Backspace/repetición, Enter/Escape, alternar show/hide, no robar foco ni dejar
modificadores presionados. Probar también terminal/navegador. No declarar listo
por proceso activo o captura del teclado sin verificar texto en destino.

Confirmar enfoque con usuario; luego diseño/plan y pruebas aisladas. Si prima
la fiabilidad inmediata sobre teclas QML, evaluar wvkbd+control Quickshell antes
de mantener un backend nuevo.

## Relevant Files

- Este informe — fuentes/alcance/puntos a validar para la siguiente tarea.
- `dotfiles/config/profiles/wayland/.config/quickshell/` — integración futura
  compartida de overlays/servicios, no modificada.
- `tests/helpers/wayland_keyboard.py` — referencia local ya probada para
  inyección por protocolo/teclados reales en tests, no backend de producción.
