# Jarq — centro de control completo y diagnóstico RDD

## Causa y alcance
Jarq seguía ejecutando el panel/backend del20deoctubre, con selector tablet automático y servicio Squeekboard. La actualización completa existía en el repositorio pero no había sido desplegada en su fuente Sway activa. No era un fallo del botón Waybar: ya llamaba correctamente a `orgm-sway control`.

## Aplicado sin switch/reboot
- Panel actual con44controles: entrada/sesión, conexiones/sonido, reproducción, energía,10workspaces, apariencia y herramientas. Componentes MenuButton y endpoints de inspección actualizados juntos.
- Backend actualizado SOLO en su bloque de centro de control. Conservadas byte a byte las funciones fuera de ese bloque, incluidos botones táctiles de cerrar/fullscreen del overview de Jarq. No se sustituyó `shell.py`: conserva las capacidades de Sway nativo y la generación de includes sin efectos SwayFX. Tampoco se sustituyó WindowSwitcher.qml.
- Política tablet manual, generador de barra reducida/grande y dispatcher de dock con sus recursos. La barra/dock cambian únicamente al activar el modo manual; no se cambió el modo del usuario ni se reinició la barra/dock para la prueba.
- Teclado Quickshell compartido instalado con motor nativo ya probado; listo y cerrado al verificar. Botón/gesto siguen la política tablet manual. Servicio automático `orgm-sway-tablet` detenido y enmascarado, retirando Squeekboard de esa sesión sin desactivar dispositivos físicos.
- Reiniciado solamente el servicio de menús para cargar el nuevo panel; agregado servicio OSK y drop-in que antepone el selector manual al comando original del dock, conservando todos sus argumentos.
- Copias selectivas tanto en HOME como en `/home/jarq/Hobby/nixos-tablet-20261020/source`; manifiestos ampliados sin eliminar sus entradas anteriores. No se reemplazó el árbol completo ni módulos Nix propios de esa fuente divergente.

Abrir desde el botón **Centro de control** existente en Waybar. No requiere cerrar sesión.

## Pruebas
- Nueva prueba `control-center-deployment.test.py`: RED con la copia real antigua (`installed backend is the old incomplete control center`), GREEN con bundle preparado, manifiestos canónicos y HOME instalado de Jarq.
-6tests de catálogo/dispatch y10de tablet manual pasaron.
- UI táctil real en Sway headless privado: pasó localmente y en el propio Jarq usando su Sway nativo y componentes recién desplegados. No se envió input al escritorio real.
- En Jarq ocupado, la prueba inicial pulsaba mientras el botón seguía deshabilitado durante la actualización del backend. El fixture ahora espera habilitación y geometría estable antes de tocar, en vez de añadir sleeps arbitrarios o cambiar la UI para la prueba.
- Teclado nativo privado:8casos Rofi (acentos,AltGr,etc.), gesto y reconexión de motor pasaron;7tests estáticos OSK pasaron.
- Estado real:44controles y todas sus herramientas presentes; OSK ready/cerrado; servicio automático masked; menús/barra/VNC/túnel activos. Generación NixOS original y procesos Firefox del usuario conservados. `git diff --check` limpio. Sin commit/push.

## Copias y siguiente rebuild
Backup de archivos fuente/HOME, enlaces, permisos y estado de servicios:
`/home/jarq/.local/state/orgm-control-upgrade/backups/20261023T055331Z/index.json`.
Motor con raíz GC `/home/jarq/.local/state/orgm-control-upgrade/osk-engine`.

Los archivos unit/drop-in temporales llevan exactamente `# orgm-control-center temporary activation`. Al reconciliar la fuente de Jarq con los módulos canónicos OSK/tablet para un futuro switch, retirar SOLO los archivos con ese marcador (`~/.config/systemd/user/orgm-osk.service` y `orgm-sway-dock.service.d/90-orgm-manual-tablet.conf`) y su enlace wantedBy propio, una vez disponibles las unidades declarativas equivalentes, y daemon-reload. De lo contrario podrían ocultar futuras actualizaciones de unidades/paquetes. No ejecutar el target canónico Jarq i3 sobre esta instalación Sway divergente. El mask del servicio automático refleja la política vigente de retirarlo.

## RDD Process — diagnóstico, no modificación
El usuario confirmó vídeo en reproducción. PID329313 corresponde al ejecutable Firefox158.0, proceso RDD; la muestra de6segundos mostró36.3%de UN núcleo (Jarq tiene4CPU lógicas), no36%de todo el equipo. RDD decodifica multimedia según [Mozilla](https://firefox-source-docs.mozilla.org/media/review/ipc.html).

La inspección no mostró FD DRM ni driver VA-API Intel cargado en RDD. La comprobación real `vainfo --display drm --device /dev/dri/renderD128` confirmó fallo de vaInitialize: no encuentra iHD/i965 en el sistema. Se identificó GPU Intel8086:1616. Falta configurar el driver de decodificación apropiado y comprobar los códecs soportados; no se promete acelerar todos los formatos con ese hardware. No se alteraron preferencias, sandbox, pestañas ni procesos Firefox; optimizar VA-API queda pendiente separado del centro de control. Herramienta vainfo usada desde Nix store, sin instalación global ni switch.
