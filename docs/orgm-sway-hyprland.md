# ORGM: entorno Hyprland basado en Sway

## Targets y estado

- `orgm`: Hyprland independiente de Ryoku, basado en el entorno Sway existente.
- `orgm-ryoku`: alternativa Ryoku conservada, con su configuración propia.
- `envy`: continúa en Sway. Los demás hosts conservan su escritorio.

El sistema y los dotfiles editables se aplican por separado. Un build no
reemplaza una configuración antigua de Ryoku en HOME: Home Manager debe
terminar su activación y las aplicaciones existentes se actualizan con un
`orgm-dot pull` explícito, con respaldo. Revisar la migración antes de cerrar
la sesión actual.

## Qué se comparte

`dotfiles/config/profiles/wayland` es una capa de orgm-dot para Sway y Hyprland,
anterior al perfil concreto. Las capas personales y del host siguen teniendo
prioridad. No importa la configuración entera de Sway dentro de Hyprland.

- Quickshell: menús de control/audio/portapapeles/ventanas/perfiles/energía/fondos
  y OSD, sin ejecutar la shell completa Ryoku.
- Reloj y calendario de escritorio derivados de Ryoku, con atribución y licencia.
- Recursos Rofi y Swaync. Waybar y el dock mantienen sus backends nativos.

Los comandos `orgm-sway` y `orgm-sway-desktop` conservan su interfaz.
`orgm-hyprland` y `orgm-hyprland-desktop` usan la misma UI con un adaptador
Hyprland para clientes, monitores, foco, workspaces, fondos y capturas.

El selector de ventanas Hyprland usa **iconos, no miniaturas capturadas**:
no se reemplaza una captura de ventana por un recorte del escritorio que pueda
mostrar otra ventana. La captura interactiva usa Hyprshot.

## Widgets

Archivo editable: `~/.config/orgm-desktop/widgets.json`. El reloj inicial es
digital, 24 horas, sin segundos y con fecha debajo. El calendario permite
mes anterior/siguiente y volver a hoy, con números de semana. No añade
sincronización de eventos ni servicios externos de calendario.

```bash
orgm-desktop-widgets settings
orgm-desktop-widgets edit
orgm-desktop-widgets done
qs --path ~/.config/quickshell/orgm-desktop ipc call widgets status
qs --path ~/.config/quickshell/orgm-desktop ipc call widgets reload
```

Los widgets se muestran debajo de las aplicaciones, sin reservar espacio ni
capturar el teclado. Su geometría se ajusta a pantallas pequeñas/escaladas.
No leen ni modifican `~/.config/ryoku/widgets.json`.

**Centro de control → Editar widgets** abre una capa de edición sobre las
ventanas, también accesible con `orgm-desktop-widgets edit`. Arrastrar el reloj
o calendario guarda su posición al soltar el ratón. Las posiciones se guardan
por nombre de pantalla en `screens` dentro del mismo JSON; no se fuerza el
calendario debajo del reloj cuando se elige una posición libre.

La barra de edición permite mostrar/ocultar cada widget, incluso si ambos están
ocultos. **Terminar** o **Esc** sale del editor y bloquea el arrastre, sin
desactivar los controles normales del calendario. El modo de edición no se
guarda: cada inicio comienza bloqueado; posiciones y visibilidad sí persisten.
Un error al guardar aparece en el editor y no sobrescribe un JSON inválido.

## Sesión Hyprland

`orgm-hyprland-session` sigue el socket de eventos de su compositor. Restaura
perfil visual/fondo/estado de juego y arranca `orgm-hyprland-session.target`.
Cuando el socket se cierra, detiene sus servicios: menús, widgets, Waybar,
dock, Swaync, idle y portapapeles. Los cambios de paleta reinician el dock
a través de su unidad, sin lanzar una segunda instancia fuera de systemd.

El dock derecho reserva su propio ancho mediante su zona exclusiva. No se
añade una segunda reserva manual en `gaps_out`; el modo normal mantiene el
mismo hueco entre ventanas en los cuatro lados. Tanto la ventana GTK como
su caja interior tienen fondo transparente, independientemente del tema GTK.

Se conserva el modelo de **una sesión gráfica activa por usuario**, igual que
las unidades de sesión Sway existentes; no se promete ejecutar simultáneamente
Sway e Hyprland con el mismo HOME y gestor systemd de usuario.

## Caffeine

El centro de control incluye **Caffeine**, sincronizado con el inhibidor nativo
de Waybar. Evita las acciones automáticas por inactividad sin detener
`swayidle`/`hypridle`, ni deshabilitar el bloqueo manual o el bloqueo antes de
suspender. Su estado se conserva en `~/.local/state/waybar/caffeine`.

Un clic en el módulo nativo de Waybar sincroniza todas las barras de ese mismo
proceso y persiste la elección. Desde el centro se reinicia únicamente la barra
de la sesión para aplicar `start-activated`; si esa operación falla, se revierte
la preferencia y se muestra un error. El control no se ofrece como activo si su
barra no está funcionando.

Sway usa `orgm-sway-waybar` para generar la configuración de arranque sin
sobrescribir el archivo editable, incluidos comentarios y comas finales JSONC.
Ese cambio de unidad requiere actualizar el perfil Sway; en Hyprland se usa el
generador existente de `hypr-display-targets`.

## Syncthing y Tailscale

En orgm Hyprland se conservan Syncthing y el daemon Tailscale, pero se retiran
sus trays del helper personal y se ocultan sus entradas XDG de autoinicio.
Syncthing tiene unidad de usuario independiente de la bandeja.

Al activar posteriormente, los launchers anteriores y enlaces antiguos de
unidades Syncthing pertenecientes a paquetes Nix se archivan bajo
`~/.local/state/orgm-desktop/desktop-cleanup-v1/`. No se borran cuentas,
configuración del cliente ni datos sincronizados; una unidad personalizada
que no pertenezca a esos paquetes se conserva.

## Aplicación futura, solo cuando se decida

Los dotfiles son copias editables. Un build no sobrescribe automáticamente
archivos personales existentes: revisar `orgm-dot list`, `orgm-dot diff APP`
y actualizar explícitamente las aplicaciones afectadas con `orgm-dot pull APP`
cuando se quiera aplicar. La capa compartida requiere la versión actualizada
de orgm-dot; no basta copiar solo el nuevo `hyprland.lua`.

Aplicaciones relevantes: `hyprland`, `wayland-tools`, `sway-wallpapers`,
`desktop-widgets`, `waybar`, `rofi`, `swaync`, `nwg-dock-hyprland`, `desktop-tools`.
Los nombres históricos `sway-wallpapers` y `swaync` ahora también pueden tener
recursos seleccionados en Hyprland. Revisar backups antes de cada `pull`.

Antes de dar una migración por validada, comprobar el arranque de Home Manager,
los servicios gráficos y los monitores reales. Suspensión y Qylock/SDDM se
validan por separado: el parser Lua y los tests de backend no sustituyen esas
pruebas.

## Verificación sin despliegue

- Las regresiones independientes de build pasan; también los tests Go,
  las evaluaciones Nix de ambos targets y server (IFD deshabilitado), y el parser
  Lua real de Hyprland con los overrides de osmarg.
- Sesión Sway privada: widgets simultáneos con menús, clipboard, audio y
  miniaturas; geometría/escalado/hotplug de los widgets comprobados por separado.
- Editor: arrastre y botones reales, salida con Esc, bloqueo normal, posiciones
  por pantalla, recuperación tras error y persistencia después de reiniciar.
- Caffeine: Waybar con dos barras y swayidle reales en sesión privada; tanto el
  clic nativo como el centro bloquean/restauran el timeout sin parar swayidle.
- Dock: estilos evaluados con GTK3 real (ventana y caja con alfa cero) y reserva
  Lua sin margen derecho duplicado.
- Qylock admite la identidad nativa de Hyprland sin exigir SWAYSOCK. Sus tests
  mantienen la confirmación segura obligatoria; no son una prueba PAM real.
- Waybar admite configuración objeto o array, monitor seleccionado y Caffeine.
  Los workspaces con nombres como `previous` se seleccionan literalmente.

La integración que construye las copias de dotfiles sigue pendiente. Dos
regresiones antiguas no quedan validadas: una compara texto obsoleto de udiskie;
otra necesita un xdg-utils del store no realizado. No se declara toda la suite
ni el despliegue en hardware como verificados.

## Consulta: LocalSend sin escritorio

Upstream documenta un cliente terminal separado, `localsend-cli`, por ejemplo:

```bash
localsend-cli send --to 192.168.1.20 archivo.pdf
```

Fuente: [README oficial de LocalSend](https://github.com/localsend/localsend/blob/main/README.md#command-line-interface).
No confundirlo con `--hidden`, que solo oculta la aplicación gráfica en el tray.
Los inputs fijados en este repositorio ofrecen LocalSend 1.17.0 y no tienen
el atributo `localsend-cli`; no se ha instalado ni empaquetado aquí el cliente
terminal, ni se han actualizado inputs.
