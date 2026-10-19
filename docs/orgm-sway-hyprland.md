# ORGM: entorno Hyprland basado en Sway

## Targets y estado

- `orgm`: Hyprland independiente de Ryoku, basado en el entorno Sway existente.
- `orgm-ryoku`: alternativa Ryoku conservada, con su configuración propia.
- `envy`: continúa en Sway. Los demás hosts conservan su escritorio.

Estos cambios están **preparados en el repositorio, no desplegados**. No se ha
hecho build ni switch de orgm, ni se ha reiniciado su sesión.

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
qs --path ~/.config/quickshell/orgm-desktop ipc call widgets status
qs --path ~/.config/quickshell/orgm-desktop ipc call widgets reload
```

Los widgets se muestran debajo de las aplicaciones, sin reservar espacio ni
capturar el teclado. Su geometría se ajusta a pantallas pequeñas/escaladas.
No leen ni modifican `~/.config/ryoku/widgets.json`.

## Sesión Hyprland

`orgm-hyprland-session` sigue el socket de eventos de su compositor. Restaura
perfil visual/fondo/estado de juego y arranca `orgm-hyprland-session.target`.
Cuando el socket se cierra, detiene sus servicios: menús, widgets, Waybar,
dock, Swaync, idle y portapapeles. Los cambios de paleta reinician el dock
a través de su unidad, sin lanzar una segunda instancia fuera de systemd.

Se conserva el modelo de **una sesión gráfica activa por usuario**, igual que
las unidades de sesión Sway existentes; no se promete ejecutar simultáneamente
Sway e Hyprland con el mismo HOME y gestor systemd de usuario.

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

Quedan pendientes build de orgm, arranque real, hardware NVIDIA/monitores,
suspensión y prueba de Qylock/SDDM en esa máquina. El parser Lua y los tests de
backend no sustituyen esas pruebas.

## Verificación sin despliegue

- 29 scripts de regresión independientes de build pasan; también los tests Go,
  las evaluaciones Nix de ambos targets y server (IFD deshabilitado), y el parser
  Lua real de Hyprland con los overrides de osmarg.
- Sesión Sway privada: widgets simultáneos con menús, clipboard, audio y
  miniaturas; geometría/escalado/hotplug de los widgets comprobados por separado.
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
