# Envy — selector y acceso remoto aplicados

## Aplicado
Envy recibió **Conectar a equipo** con la misma política: solamente Linux online visibles en Tailscale, propios/compartidos, excluyendo Self. Opciones: escritorio privado si está preparado, terminal SSH con autenticación normal. Remmina Flatpak1.4.43 instalado por usuario con remoto Flathub; override limitado al directorio runtime de sockets.

Acceso de escritorio preparado en ambos sentidos **Envy ↔ OrgM** y **Envy ↔ Jarq**. Solo se intercambiaron claves PÚBLICAS por SSH previamente verificado. La nueva clave privada de Envy permanece allí,0600; claves autorizadas restringidas por IP Tailscale de origen, sin shell/PTY/agent/X11 y con forwarding permitido. Host keys fijadas por alias dedicado. Las claves normales de SSH terminal son independientes y no se copiaron.

## Respeto de configuración actual
Envy está en Sway, con fuente mutable real `/home/osmarg/Hobby/nixos-osk-switch-20261021-Gvlor6/source`. Se añadieron solo manifiesto/helper/selector/desktop entry nuevos y perfiles privados; no se reemplazaron configuraciones SwayFX, shell, tablet, temas o Git del usuario. `orgm-dot pull remote-desktop` creó backup `20261023T154438.853335723-remote-desktop-pull`.

WayVNC privado mantiene portapapeles deshabilitado por el fallo ya diagnosticado, captura de una salida disponible (sin el mosaico vulnerable al hotplug), Restart=always, LimitCORE0 y transporte Unix/SSH. Servicios nuevos del usuario ligados a sway-session.target y plantilla de túnel foreground supervisada. Marcador temporal exacto compatible con la migración declarativa canónica. Dependencias con raíz GC privada; nada de VNC por TCP ni cambios de firewall.

No se hizo switch, reboot, restart de Sway ni inyección de input/captura persistente de pantallas reales. Generación original de Envy conservada: `/nix/store/gxbhlp0d7cni8s9g69kdp8gbqf3jmy3h-nixos-system-envy-sway`.

## Verificado
-3ciclos captura/reconexión por cada ruta nueva: Envy→OrgM2560x1440, Envy→Jarq1920x1080, OrgM→Envy1920x1080 y Jarq→Envy1920x1080. Frames descartados, sin screenshots guardados ni input.
- En cada ruta la clave dedicada VNC autenticó pero rechazó ejecutar una shell (exit1, sin stdout).
- Selector instalado en cada equipo ve ambos escritorios preparados y excluye Self; conserva filtro online-Linux.
- Motor de tema `orgm-rofi` existente de Envy validado por dump sin abrir ventana.
- Sandbox real Remmina de Envy ve ambos endpoints Unix; versión instalada1.4.43.
- Servicio Envy active/running, NRestarts0, AF_UNIX, LimitCORE0; directorio0700 y sockets0600, sin listener TCP5900–5999.
-22tests existentes del selector/transporte pasaron; git diff --check limpio. La interfaz Remmina real ya fue validada privadamente en el despliegue original; en Envy se verificaron sandbox y transporte real, no se abrió GUI sobre el escritorio del usuario.

## Backups
Envy: `~/.local/state/orgm-remote-desktop/backups/envy-prepare-20261023T154438Z` y `add-envy-20261023T154606Z` (presencia/archivos de autorizaciones, peers, host keys, units y override). OrgM/Jarq: `add-envy-20261023T154605Z` antes de agregar Envy, preservando sus peers/autorizaciones previos.

La nueva unidad de Envy usa `~/.local/state/orgm-remote-desktop/private-wayvnc` como raíz GC del backend. Al migrar a los módulos Nix canónicos se retiran SOLO unidades marcadas según el procedimiento ya documentado. No aplicar un checkout ajeno sustituyendo fuentes activas.

Sin commit/push solicitado. Usar **Win+Space → Conectar a equipo**, elegir destino y Escritorio/Terminal SSH; desde OrgM o Jarq también aparece Envy como escritorio preparado.
