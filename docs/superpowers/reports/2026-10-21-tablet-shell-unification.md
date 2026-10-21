# Teclado seguro y perfil tablet manual — 2026-10-21

## Goal
Unificar teclado Quickshell Sway/Hyprland, eliminar tablet automático, ofrecer barra/dock táctiles reducidos, centro de control completo y menús con el formato Win+Space. Añadir un botón de teclado dentro de SDDM y del bloqueo.

## Instructions
- Aplicar los pulls y verificar antes de pedir pruebas al usuario.
- Mantener perfil scroll y selector Alt+Tab existente; no modificar PAM, cerrar sesión, desbloquear, reiniciar SDDM/equipos ni hacer commit/push.
- Jarq: el usuario indicó sufijo98; se intentó10.0.0.98 con verificación SSH estricta.
- No recoger ni reutilizar contraseñas en la conversación. La activación administrativa espera respuesta a la solicitud de autorización gráfica.

## Discoveries
- El despliegue activo de Envy conservaba un controlador automático que iniciaba Squeekboard; sustituir solo el servicio del teclado no bastaba.
- Caffeine necesita un módulo idle_inhibitor realmente instanciado; la configuración/persistencia sola no inhibe reposo.
- accepted() y Keys.onReturnPressed no son equivalentes.24temas necesitan un puente local de su manejador original; los onAccepted existentes se conservan, incluidos sus guardas.
- Rofi puede ignorar configuration.font si el tema fija *.font/prompt.font. Se verificaron18px efectivos con el Rofi real.
- Envy tiene cambios de Sway nativo y cierre/fullscreen táctiles ausentes del checkout canónico: se conservaron mediante mezcla de tres vías y selección de funciones, no sobrescritura indiscriminada.

## Accomplished
- Fuente integrada con guardas de contenido en el checkout canónico; trabajo previo ajeno preservado, sin commits.
- OrgM/Hyprland:8pulls con respaldos; menús/barra/dock/OSK activos, teclado ready; transiciones reales manual on/off verificadas y preferencia anterior off restaurada.
- Envy/Sway:6pulls con respaldos; teclado Quickshell ready, barra/dock/centro unificados; antiguo servicio automático detenido y enmascarado en runtime, ningún proceso Squeekboard. Transiciones reales normal/tablet verificadas, preferencia previa on conservada ahora como manual.
- Conservados colores dinámicos, pines del dock normal y directorio de barra Sway en OrgM. Sin cambios del perfil scroll ni del plugin Alt+Tab.
- Centro de control compartido: entrada/tablet/teclado/ventanas/espacios, brillo, salida/micrófono, audio avanzado y mezclador, red/Bluetooth, notificaciones/DND, reproducción, energía/Caffeine/Gaming, apariencia/fondos/widgets/pantallas, utilidades, bandeja y sesión. Herramientas ausentes se deshabilitan; acciones y argumentos permitidos explícitamente.
- Helpers Rofi/SSH/Firefox/símbolos utilizan el mismo tema/paleta del launcher; tres capas efectivas de Firefox corregidas.
- Teclado de autenticación puramente local Qt, sin motor global ni IPC de texto/contraseña. Botón visible y espacio reservado dentro de cada tema y respaldo del bloqueo; Return conserva el camino original, Ctrl/Alt globales deshabilitados.
- Paquete seguro construido localmente: /nix/store/fm3ams790ib18zbi4k7v7d80h4y6gikv-orgm-qylock-1.0.41temas renderizados; SDDM real en test-mode (Winter/Forest/Clockwork); bloqueo privado con dos monitores/hotplug/all-off/escala/fallback/fake-PAM; botón+Enter táctiles reales en PixelCoffee privado. No se usaron credenciales reales.
- Revisión fresca:3Important y2Minor. Se corrigieron los3Important y se elevó/corrigió el tamaño de fuente por accesibilidad tablet; una mejora menor aplazada.
- Suite enfocada completa PASS:10manual,6CC,5Caffeine,2paquete seguro,4contratos nativos de teclado seguro,6OSK y su matriz de perfiles,3estilo,6menús,10desktop,35Sway-tools, sesiones nativas de barra/dock/inhibición/CC/Rofi-OSK, Firefox/SSH/Rofi e integraciones Hyprland. No se afirma que toda la suite del repositorio esté verde.

### Estado de activación
**Los cambios de usuario están activos en OrgM y Envy. SDDM y el bloqueo de producción todavía usan su paquete anterior.** El paquete nuevo se preparó/probó pero NO se activó sin autorización administrativa nueva. No se reinició SDDM ni se tocó un bloqueo real.

Envy: fuente preparada desde su despliegue activo en `/home/osmarg/Hobby/nixos-tablet-shell-20261021-pzYsXw/source`; manifiesto de56rutas y respaldo conservados junto a `build.log`. Toplevel construido, NO activado: `/nix/store/lj35wgrgyl6vycxywdy6cwdjdb8xh7jr-nixos-system-envy-sway`. Generación anterior activa: `/nix/store/gxbhlp0d7cni8s9g69kdp8gbqf3jmy3h-nixos-system-envy-sway`. Runtime override del dock: `/run/user/1000/systemd/user/orgm-sway-dock.service.d/90-orgm-tablet-shell.conf`; retirar solo después de activar la unidad permanente nueva. La integración permanente del perfil tablet espera ese switch.

Jarq: TCP22 no responde en10.0.0.98, ni directamente ni desde Envy. No se aplicó nada allí ni se reemplazó su fuente Sway real por el antiguo target i3 del checkout.

## Next Steps
1. Recibir autorización gráfica; activar el paquete/configuración segura en Envy y OrgM sin reiniciar SDDM ni desbloquear. Envy tiene build completo preparado; OrgM requiere integrar con su generación activa sin arrastrar cambios ajenos.
2. Verificar raíz del tema, selección conservada y metadatos activos; limpiar únicamente los overrides temporales propios después del switch correcto. Login nuevo verá el botón; el bloqueo ya abierto no se recarga.
3. Recuperar conectividad/confirmar dirección completa de Jarq y aplicar sobre SU fuente Sway activa.
4. Pruebas físicas del usuario: pantalla táctil, rotación, varios monitores, audio/red/Bluetooth/bandeja, login/bloqueo normal; nunca pedir contraseña por chat.
5. Mejora menor aplazada: consultar perfiles energéticos soportados; Performance puede aparecer en equipos que no lo admiten y devolver un error de acción.

## Relevant Files
- `dotfiles/config/profiles/wayland/.local/lib/orgm-wayland/tablet.py` — política manual y generación de barra.
- `dotfiles/config/profiles/wayland/.config/quickshell/orgm-tablet-dock/` — dock táctil de tres acciones.
- `dotfiles/config/profiles/wayland/.local/lib/orgm-wayland/desktop.py` y `.../orgm-wallpapers/modules/ControlMenu.qml` — centro compartido y acciones permitidas.
- `dotfiles/config/profiles/wayland/.local/bin/orgm-rofi` — contrato único de estilo, paleta y densidad.
- `dotfiles/config/programs/shell/.config/quickshell/orgm-osk/AuthKeyboard.qml` — edición local segura, sin autenticar.
- `nixos/profiles/sway/qylock-keyboard-themes.py` y `qylock-runtime.nix` — temas inmutables con teclado y compatibilidad de Return.
- `nixos/tablet.nix`, `nixos/profiles/sway/sway.nix` — retirar automatismo e integrar ciclo del dock.
- `tests/{manual-tablet,tablet-shell-session,control-center,control-center-session,secure-keyboard-package,secure-keyboard-session,menu-style-parity,osk-session,qylock-session}.test.py` — evidencia enfocada/nativa.
- `docs/superpowers/plans/2026-10-21-tablet-shell-unification.md` — plan y límites.

## Rulings I made
- Ruling: User yes to prior direct-execution offer plus detailed corrective requirements is instruction to proceed without another design questionnaire — inline plan as engineering record, significant implementation choices announced — cost if wrong: compact tablet arrangement may need user adjustment.
- Ruling: tablet dock becomes a three-action touch navigation dock using existing Quickshell; normal nwg-dock/pins untouched — genuine reduced profile without third-party dock patches or pin mutation — cost if wrong: tablet has window-selector access rather than every task pinned directly.
- Ruling: auth keyboard reuses pure QML visual board with local Qt-field controller inside each secure/auth window; not global Wayland/XTest backend — preserves PAM/session-lock boundaries and avoids Qt InputPanel one-instance-per-process issue — cost if wrong: theme focus/Return conventions must be validated across wrapped catalog.
- Final: Ruling: Deployment/activehost/oldtablet/Jarq — verified own runtime on OrgM/Envy and stopped only Envy legacy unit; permanent root activation and Jarq remain pending — cost if wrong: cannot promise next-login or Jarq readiness.
- Final: Ruling: Envy three-way preservation — retained nativeSway capability changes and stable-ID close/fullscreen; generated merge manifest and built stage — cost if wrong: unrelated deployed features could regress if merge was incorrect.
- Final: Ruling: Real passwords/PAM/productionunlock — deliberately excluded; only private fake PAM/test token and SDDM test mode — cost if wrong: physical user confirmation still required.
- Final: Ruling: Preexisting lock/PAM/upstream securityaudit — no authentication/PAM/supervision changes; audited only new local widget and compatibility bridges — cost if wrong: not a comprehensive security certification.
- Final: Ruling: Physical touchscreen/palm/hotplug/rotation/resume/scaling — virtual pointer and private output hotplug tested, physical behavior not certified — cost if wrong: device-specific adjustments may remain.
- Final: Ruling: NativeHyprland/plugins/AltTab — existing plugin/layout untouched; current Hyprland service transitions tested without input — cost if wrong: physical AltTab interaction not retested.
- Final: Ruling: All41theme keyboard interaction — all41render;24Keys-only editable fields bridged; dummy accepted/guarded/conditional contracts and PixelCoffee real packaged touch/fakePAM tested — cost if wrong: not every theme interaction tested end-to-end.
- Final: Ruling: Systemd concurrency/failure/crosssession/duplicates — unit wrong-display rejection plus private command-boundary rollback and real current on/off service transitions; no claim of exhaustive races — cost if wrong: parallel external toggles may have untested rollback race.
- Final: Ruling: Tablet dock multimonitor/hotplug — single explicit preferred/default screen; touch fixture single-output; lock protocol hotplug separate — cost if wrong: tablet dock monitor hotplug not physically proven.
- Final: Ruling: Tray/hardware/network/Bluetooth/power — use existing native managers/tray APIs; advancedaudio explicit; availability checks command based with no fake hardware success claims — cost if wrong: hardware workflows require physical verification; unsupported Performance remains deferred.
- Final: Ruling: Fullrepo/independentNix/permanentintegration — focused suite and own package plus Envy complete toplevel built; no fullrepo or already-active-system claim — cost if wrong: unrelated tests and root activation remain outside completed evidence.

## Deferred minors
- Detectar perfiles energéticos soportados antes de ofrecer Performance.

## Key Learnings:
1. Un perfil visual reducido debe mantener vivos los mecanismos funcionales ocultos, como Caffeine.
2. El teclado de SDDM/bloqueo debe editar solamente el campo Qt local; no reutilizar la inyección global del teclado de sesión.

## Corrección posterior de despliegue
Win+Space reveló que el helper compartido no se instalaba desde la antigua capa programs/rofi. Corregido y verificado mediante pulls reales y launcher activo; ver [reparación del launcher](2026-10-21-orgm-launcher-repair.md). Para el switch pendiente de Envy reconstruir la nueva fuente indicada allí.

## Actualización de cierre tras el switch de OrgM
El usuario confirmó que el switch terminó correctamente y pidió commit/push.
Se verificó de forma independiente que `/run/current-system` y el perfil
predeterminado apuntan ambos a
`/nix/store/d8696fsbs33jxyh1g6s80hhzwcaxiw0f-nixos-system-orgm-hyprland`,
la generación completa construida desde `.#orgm` con estos cambios.
La preparación de OrgM ya no espera activación; no se hicieron pruebas nuevas
de credenciales, login, desbloqueo real ni reinicio de SDDM. El estado pendiente
de Envy/Jarq descrito anteriormente no cambia por este switch de OrgM.
