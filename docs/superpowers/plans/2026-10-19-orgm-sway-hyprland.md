# ORGM Sway → Hyprland Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir widgets Ryoku a Sway y preparar orgm Hyprland equivalente, conservando orgm-ryoku sin desplegar.

**Architecture:** Recursos Quickshell compartidos, capa de dotfiles Wayland limitada a Sway/Hyprland y backends de compositor separados. Preservar interfaces Sway, personalizaciones editables y límites host/server.

**Tech Stack:** NixOS/Home Manager, Go (orgm-dot), Python, QML/Quickshell, Lua Hyprland, Sway IPC y Hyprland IPC.

**Spec:** `docs/superpowers/specs/2026-10-19-orgm-sway-hyprland-design.md`

## Global Constraints

- No hacer build ni switch de orgm todavía; tampoco `nix run`, `nix shell`,
  pruebas con IFD o comandos que construyan dependencias sin autorización.
- No actualizar inputs ni modificar otros hosts/escritorios.
- Sway actual es la referencia funcional y visual: conservar Waybar, dock y swaync.
- Reloj inicial digital, 24 horas, sin segundos y fecha inline debajo.
- Mantener Syncthing y Tailscale; retirar únicamente sus bandejas del inicio de orgm.
- No modificar archivos reales de HOME ni reiniciar servicios/sesiones reales.
- Comandos shell con prefijo `rtk`; los ejemplos siguientes lo incluyen.
- Commits de implementación por tarea, únicamente con archivos propios; no push.

## Review Focus

- HOME editado: orgm-dot no debe sobrescribir personalizaciones ni Ryoku al compartir recursos.
- Pantallas pequeñas/escaladas o hotplug: widgets visibles dentro de pantalla y sin robar foco.
- Títulos/rutas con comillas: pasar argumentos como listas; ninguna interpolación de shell del backend.
- Dos sesiones o reapertura de menús: PID/IPC/caché privados por sesión; sin procesos duplicados.
- Modo server y alternativa Ryoku: no heredar nuevos procesos gráficos; sincronización/VPN preservadas.

---

## Task 1: Capa Wayland y widgets en Sway

**Files:**
- Modify: `nixos/orgm/orgm-dot-src/config.go`, `nixos/orgm/orgm-dot-src/sync_test.go`
- Create: `dotfiles/config/profiles/wayland/.config/quickshell/orgm-desktop/`
  (`shell.qml`, `config/Settings.qml`, `modules/DesktopClock.qml`,
  `modules/DesktopCalendar.qml`, `NOTICE.md`, `COPYING`, módulos de fecha necesarios).
- Create: `dotfiles/config/profiles/wayland/.local/bin/orgm-desktop-widgets`
- Create: `dotfiles/apps/desktop-widgets.json`
- Modify: `nixos/profiles/sway/sway.nix`
- Test: `tests/desktop-widgets.test.py`, `tests/desktop-widgets-session.test.py`

**Interfaces:**
- Consumes: Quickshell ya instalado y paleta activa de orgm-visual-profile.
- Produces: `orgm-desktop-widgets daemon`; IPC `widgets status` devuelve JSON
  con pantalla, geometría, diseño, fecha y estado de calendario; configuración
  editable `~/.config/orgm-desktop/widgets.json` con defaults de la spec.
- `Runtime.collect()` aplica `profiles/wayland` solo para Sway/Hyprland,
  después de programas y antes del perfil concreto; usuario/host mantienen prioridad.

- [ ] Write failing Go tests: archivo compartido presente en sway/hyprland,
  ausente en ryoku/i3; override perfil/usuario/host gana; edición HOME se conserva.
- [ ] Run `rtk proxy go test ./...` en `nixos/orgm/orgm-dot-src`; comprobar fallo esperado.
- [ ] Implementar capa; añadir pruebas Python de defaults, configuración ausente,
  JSON inválido y aislamiento respecto a `~/.config/ryoku/widgets.json`.
- [ ] Ejecutar `rtk proxy python3 tests/desktop-widgets.test.py`; comprobar fallo.
- [ ] Adaptar reloj/calendario originales desde input Ryoku fijado
  `28c5207586babb136aecf8568ce3ed873fa8f8fd`; guardar licencia/atribución.
  No cargar servicios Ryoku ni sus singletons completos. Calendario mensual
  permite anterior/siguiente/hoy, muestra fecha actual y números de semana.
- [ ] Añadir servicio `orgm-desktop-widgets` perteneciente a sway-session.target,
  con PATH de helpers, parada al salir y sin activación en consola.
- [ ] Probar sesión privada siguiendo `tests/sway-menus-session.test.py`:
  reloj+calendario renderizan, ventanas normales quedan encima, no se captura
  teclado, pantalla 1280x720/scaling y hotplug ajustan geometría, reinicio no duplica.
- [ ] Ejecutar tests Go, Python y sesión con binarios ya instalados; si faltan,
  registrar prueba pendiente sin instalar/construir. Commit solo tras verificar.

## Task 2: Compartir UI y separar backend de compositor

**Files:**
- Move: `dotfiles/config/profiles/sway/.config/quickshell/orgm-wallpapers/`
  → `dotfiles/config/profiles/wayland/.config/quickshell/orgm-wallpapers/`
- Create: `dotfiles/config/profiles/wayland/.local/lib/orgm-wayland/desktop.py`
- Modify: `dotfiles/config/profiles/sway/.local/bin/orgm-sway-desktop`
- Modify: `dotfiles/config/profiles/sway/.local/bin/orgm-sway`
- Modify: tests `sway-{desktop,menus,wallpapers}*.py` y
  `sway-{desktop,menus,wallpapers}*-session.test.py` para cargar capa+perfil.

**Interfaces:**
- Mantener CLI actuales `orgm-sway` y `orgm-sway-desktop` sin cambios observables.
- Compartir presentación, catálogos, clipboard/audio y ciclo de menús.
- Contrato Python de backend: `outputs() -> list[dict]`,
  `windows() -> list[dict]`, `focus_window(id: str) -> None`,
  `active_output() -> str`, `logout() -> None`,
  `capture_window(id: str, destination: Path) -> bool` y
  `subscribe() -> Iterator[str]`. IDs opacos; ventanas normalizadas con
  `id`, `title`, `app_id`, `output`, `workspace`, `focused`, `rect`.

- [ ] Añadir tests de equivalencia de catálogos antes/después de extracción,
  títulos/rutas con comillas y dos sesiones sin colisión de IPC/caché.
- [ ] Ejecutar tests para observar fallos del contrato nuevo.
- [ ] Extraer solo lógica independiente; operaciones Sway permanecen en adaptador.
  Mantener namespaces IPC y rutas finales instaladas para no romper clientes.
- [ ] Ejecutar `rtk proxy python3 tests/sway-desktop.test.py`,
  `rtk proxy python3 tests/sway-menus.test.py`,
  `rtk proxy python3 tests/sway-wallpapers.test.py` y sesiones privadas existentes
  (modo on-demand y daemon). Commit tras pasar regresión disponible.

## Task 3: Hyprland equivalente a Sway

**Files:**
- Create: `dotfiles/config/profiles/hyprland/.local/bin/orgm-hyprland-desktop`
- Create: `dotfiles/config/profiles/hyprland/.local/lib/orgm-wayland/hyprland.py`
- Modify: `nixos/profiles/hyprland/hyprland.nix`
- Modify: `dotfiles/config/profiles/hyprland/.config/hypr/lua/`
  (`autostart.lua`, `programs.lua`, `keybindings.lua`, `look-and-feel.lua`).
- Modify: `dotfiles/config/profiles/hyprland/.config/waybar-hypr/{config,style.css}`
- Modify: `dotfiles/config/profiles/hyprland/.local/bin/hypr-nwg-dock`
  y `nixos/profiles/sway/qylock.nix` (permitir Hyprland sin cambiar política PAM).
- Test: `tests/hypr-sway-parity.test.py`, `tests/hypr-sway-session.test.py`;
  actualizar regresiones Hyprland afectadas por cambios aprobados.

**Interfaces:**
- `orgm-hyprland-desktop` expone los comandos actuales de
  `orgm-sway-desktop`, usando UI compartida y backend del contrato Task 2.
- Hyprland usa hyprctl JSON/eventos socket2; no swaymsg ni SWAYSOCK.
- Compartir widgets/lock/OSD/menús; Waybar/dock mantienen módulos nativos Hyprland.

- [ ] Escribir tests con fixtures JSON de monitores/clientes y eventos:
  normalización, pantalla activa, foco por address, workspace y captura por ventana;
  probar ventanas cerradas durante selección y comandos/rutas maliciosas como datos.
- [ ] Ejecutar tests y observar fallo; implementar adaptador con argv, sin shell.
  Para capturas usar protocolo disponible en Hyprland (no asumir que grim sirve);
  si no hay captura disponible, mostrar icono y no una imagen incorrecta de pantalla.
- [ ] Añadir pruebas de bindings equivalentes a Sway, logout con confirmación,
  ctrl audio/clipboard, fondos estáticos/video y paleta de perfiles; implementar.
- [ ] Sustituir configuración visual heredada por equivalente Sway y adaptar dock
  derecho con reserva de espacio. Usar swaync, no dunst en paralelo. Conservar
  opciones específicas de monitores/dispositivos del host y portal KDE Connect.
- [ ] Servicios de sesión: menus, widgets, notificaciones, idle/lock y clipboard,
  una instancia por sesión. Qylock operativo sin volver a configurar fingerprint.
- [ ] Ejecutar regresiones Hyprland existentes y sesión Hyprland privada cuando
  binario/backend headless disponibles; reportar límites sin tocar sesión real.
  No afirmar que previews funcionan si solo se verificó fallback. Commit verificado.

## Task 4: Targets orgm y continuidad sin trays

**Files:**
- Modify: `configurations.nix`, `tests/fixtures/nixos-configurations.txt`
- Modify: `nixos/common-dotfiles.nix` y, si corresponde, `nixos/common.nix`
- Modify: `tests/configuration-inventory.bats.sh`, `tests/flake-outputs.bats.sh`
- Modify: `tests/orgm-boot-specialisations.bats.sh`, `tests/hypr-tray-applets.bats.sh`
- Create: `tests/orgm-hyprland-transition.bats.sh`

**Interfaces:**
- `nixosConfigurations.orgm` usa descriptor histórico `orgm-hyprland`;
  `nixosConfigurations.orgm-ryoku` usa `orgm-ryoku`, mismo host y usuario.
- Syncthing cuenta con unidad de usuario independiente de bandeja en ambos targets.
- Tailscale conserva daemon/red; no nuevos applets de inicio para orgm.

- [ ] Tests fallan exigiendo seis outputs (cinco hosts + alternativa orgm-ryoku),
  descriptor orgm Hyprland y ausencia de cambios en otros hosts.
- [ ] Implementar inventario y actualizar comparaciones históricas intencionales,
  sin debilitar pruebas de NVIDIA/kernel/discos/audio/server.
- [ ] Escribir test evaluado de Syncthing/Tailscale habilitados, ausencia de entradas
  de bandeja activas, y `server` sin widgets/menús/login gráfico; ejecutar RED.
- [ ] Extender condición de unidad Syncthing a orgm Hyprland; cubrir entradas XDG
  y personalizaciones persistentes con ocultación/retirada acotada y copia de
  seguridad, sin borrar configuración del cliente ni datos de sincronización.
- [ ] Evaluar ambos targets y especializaciones con `nix eval`, sin construir.
  Comprobar Ryoku sigue separado y preferencias editables intactas. Commit verificado.

## Task 5: Verificación global y entrega sin desplegar

**Files:** `INSTALL.md`, `nixos/profiles/ryoku/README.md` y este plan.

- [ ] Documentar dos targets, base Sway, archivos compartidos y pasos de validación
  futura. Corregir documentación que aún afirme salida pública única para orgm.
- [ ] Ejecutar todas las pruebas independientes de build; inventariar antes los
  scripts para no lanzar comandos que construyan, hagan SSH o cambien host real.
  Reportar cada fallo/preexistente y cada prueba omitida por restricciones.
- [ ] Usar verification-before-completion y solicitar revisión de cambios; corregir
  hallazgos con pruebas antes de afirmar funcionalidad.
- [ ] `rtk git diff --check`; revisar status/diff final y actualizar checkboxes solo
  con evidencia. No declarar integración runtime en orgm ni prueba de hardware.
- [ ] Entregar resumen de cambios/pruebas y build/switch explícitamente pendientes;
  no push, build, switch ni reboot.
