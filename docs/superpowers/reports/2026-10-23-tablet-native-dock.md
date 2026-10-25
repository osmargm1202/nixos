# Tablet — dock nativo grande en Envy y OrgM

## Instrucción vigente
El usuario reportó la barra casi sin iconos y la ausencia del dock esperado en Envy. Después aclaró en OrgM que veía dos botones de teclado y necesita **conservar el dock de aplicaciones con iconos mayores**. Esta instrucción reemplaza el diseño previo que sustituía todo el dock por una tira Quickshell Apps/Ventanas/Teclado.

## Corrección aplicada
- Sway: el dispatcher usa el mismo comando nativo, posición, launcher, flags y favoritos. Solo cambia `-i32` por `-i48` al estar activado el modo tablet manual.
- Hyprland: el wrapper habitual selecciona32/48 según la política manual; no redirige a la tira Quickshell. Se conservan toda su propiedad PID/starttime/sesión, foco de aplicaciones y reglas de inicialización de favoritos.
- No se lanza la tira de tres botones. Queda el botón flotante de teclado ya existente en modo tablet; el teclado sigue accesible desde el centro de control. No se modificó el motor ni se cerró un teclado abierto manualmente.
- Waybar reducido mantiene reloj/estado y el centro de control con **icono+texto Control**,24px y objetivo táctil grande. La prueba anterior mostraba solo un pequeño engranaje, no los iconos del perfil normal: era la reducción deliberada del perfil, no un fallo demostrado de las fuentes o del compositor.
- Configuración normal permanece intacta:32px al desactivar tablet. No se cambió el modo del usuario al aplicar. No se tocaron pines, estado de ventanas ni hardware/entradas.

## Despliegue
Aplicado selectivamente a HOME y fuentes activas de OrgM/Envy. Se recargaron solamente sus servicios de barra/dock mediante el helper con comprobación de identidad de sesión. Ambos estaban off y permanecieron off; dock nativo32px comprobado en vivo. No se hizo switch/reboot/restart de Sway/Hyprland ni se inyectaron teclas en sesiones reales.

En Envy la fuente mutable aún contenía la política tablet automática antigua aunque HOME ya tenía la manual, y el dispatcher solo existía en HOME. La prevalidación detuvo el primer intento antes de escribir. Tras comparar y reconocer exactamente esa versión vieja, se actualizó también la fuente de tablet, se añadió el dispatcher al manifiesto y se preparó el comando del módulo Sway para el próximo rebuild, preservando el resto de su SwayFX.

La unidad activa de Envy dependía de un drop-in en /run que se perdía al reiniciar. Se añadió uno persistente en `~/.config/systemd/user/orgm-sway-dock.service.d/90-orgm-tablet-shell.conf`, marcado `# orgm-tablet native-dock temporary activation`. Usa `/run/current-system/sw/bin/nwg-dock` para no fijar un store path antiguo. Cuando el módulo declarativo actualizado esté activo, retirar solo ese drop-in marcado si se desea que sus flags vuelvan a gobernarse exclusivamente desde Nix.

Backups: OrgM `~/.local/state/orgm-tablet/backups/native-dock-20261023T180448Z`; Envy `native-dock-20261023T180530Z`. Índices registran fuente/HOME/drop-in/manifiesto antes de cambios. El directorio Envy180448Z del intento abortado no contiene cambios aplicados.

## Evidencia
- RED: prueba detectó ausencia de `dock_command`, el reemplazo por Quickshell y el botón de Waybar sin etiqueta.
- GREEN:12tests manual-tablet;7control-center;7OSK. Bash wrapper regression conserva favoritos/propiedad de procesos y verifica32normal/48tablet.
- Prueba real privada con Sway, Waybar y nwg-dock: flags48, pines sin cambios, **píxeles reales de iconos renderizados** (no solo proceso activo), clic de Control, inhibidor Caffeine funcional y liberación al cerrar la barra de fixture. Pasó localmente y con los binarios/fuente del propio Envy.
- Artefactos antes/después pertenecen exclusivamente a esa sesión virtual, nunca al escritorio real del usuario.
- Revisión independiente de producción: sin hallazgos importantes;12tests y sintaxis Bash corroborados. La lógica de foco/PID/pines de Hyprland no fue reescrita.
- Verificación instalada: ambos servicios activos, dock nativo32 en modooff, política48 preparada y etiqueta Control; preferencias y archivos de pines comparados antes/después sin cambios. `git diff --check` limpio. No se afirma haber activado tablet sobre la sesión del usuario para esta prueba.

## Hallazgos del harness
nwg-dock y su fork comparten un lock de /tmp basado en **USER**, no en el socket Wayland. El primer intento de test solo aislaba compositor/HOME: envió SIGUSR1 al proceso que poseía ese lock. Se detuvo ese enfoque y el test exige ahora bwrap con PID, IPC, red y /tmp privados. La recarga acotada del dock solicitada por el usuario restauró su instancia normal; no se reutilizó ese enfoque inseguro.

El fixture también debe recibir la caché SVG de librsvg, igual que la unidad real. Sin ella el proceso podía estar vivo sin iconos, por lo que se añadió comprobación de píxeles. El nwg-dock0.4.3 existente usa XDG_CONFIG_HOME para pines cuando XDG_CACHE_HOME está definido; el fixture respeta ese comportamiento sin cambiarlo en producción. No asumir que un PID/argv correcto demuestra una interfaz visible.

## Uso
Activar de nuevo modo tablet desde **Control** para probar el dock de aplicaciones grande. Desactivarlo devuelve32px. No se desplegó esta revisión nueva en Jarq en esta tarea; queda en la configuración compartida para su próxima actualización.
