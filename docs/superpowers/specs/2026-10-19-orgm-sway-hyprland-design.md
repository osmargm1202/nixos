# ORGM: Hyprland basado en Sway

## Alcance aprobado

El usuario aprobó en conversación el 2026-10-19:

- Sway actual es la referencia funcional y visual: no reemplazar Waybar,
  nwg-dock ni swaync por una shell nueva.
- Añadir reloj de escritorio y calendario de Ryoku a Sway sin ejecutar la
  shell completa de Ryoku. Compartirlos posteriormente con Hyprland.
- Reloj inicial digital, 24 horas, sin segundos y fecha inline debajo.
- Hyprland reproduce aplicaciones, menús, apariencia y helpers de Sway,
  adaptando las operaciones específicas del compositor.
- Publicar `orgm` con Hyprland y conservar `orgm-ryoku` como alternativa.
- Syncthing y Tailscale siguen funcionando sin iniciar sus bandejas.
- No hacer build ni switch de orgm todavía.

## Decisiones de implementación propuestas

- Compartir únicamente recursos independientes del compositor mediante una
  capa `dotfiles/config/profiles/wayland`, cargada antes de `sway` o
  `hyprland` por orgm-dot. Nunca importar un perfil entero dentro del otro.
- Adaptar los componentes originales Ryoku, conservar atribución, revisión
  y licencia del código reutilizado. No importar su `Desktop.qml`: arrastra
  plugins, stage, visualizer y gestión del fondo.
- Configuración de widgets propia, editable y separada de Ryoku. Los valores
  actuales de `~/.config/ryoku/widgets.json` sirven de referencia, no como
  dependencia runtime ni como archivo que debamos modificar.
- Fondo y ventanas siguen siendo responsabilidad del compositor/backend.
  Las ventanas de widgets van debajo de aplicaciones, sin reservar espacio
  ni capturar el teclado al abrir una sesión.
- Mantener interfaces públicas de helpers Sway. Hyprland obtiene un adaptador
  real para ventanas, monitores, workspaces, capturas y eventos; nunca una
  sustitución textual de `swaymsg` por `hyprctl`.
- Mantener hardware, NVIDIA, audio y especialización server de orgm. La
  alternativa Ryoku conserva sus ajustes y datos.

## Fuera de alcance

Cambiar otros hosts de escritorio, rediseñar el entorno, quitar servicios de
sincronización/VPN, actualizar inputs, instalar LocalSend CLI, añadir servicios
de calendario externos o activar cambios en la sesión real del usuario.

## Aceptación

Pruebas de widgets en sesión privada Sway; regresión de menús Sway; pruebas
del backend Hyprland y validación de su configuración cuando el runtime
instalado lo permita; evaluación Nix de targets/servicios y frontera server.
Una comprobación que necesite construir se deja pendiente, no se fuerza.
