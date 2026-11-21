# Lanzamiento tmux UTF-8 — 2026-11-21

El cliente remoto de Codeman ejecuta `tmux -L codeman-remote ...` por SSH no
interactivo, sin cargar la función de Bash que añadía `-u`. Los cuatro clientes
preexistentes en ORGM informaban `client_utf8=0`.

Se añadió `server/dotfiles/.local/bin/tmux`, instalado también con `--tmux-only`.
Resuelve el binario real por PATH omitiendo su propia ruta y fuerza `-u`, conserva
argumentos/stdin y evita duplicar la opción usada por la función interactiva.
El instalador incluye staging, protección de destinos Nix, backup e idempotencia.

Activación acotada en ORGM: sólo `~/.local/bin/tmux`, sin sustituir el binario
system ni recargar el instalador completo, plugins, Bash o servicios. El PATH
observado del lanzador Codeman ya prioriza `~/.local/bin`. Comparación de bytes
con la fuente correcta. Se conservan las sesiones y procesos de los clientes
existentes: deben reconectar el cliente; no matar el servidor tmux.

Backup previo de servidor: `~/backups/orgm-admin/20261121T124209Z-acceso-privado`,
checksums, restauración PostgreSQL aislada y huellas coincidentes.

Validación: `python3 tests/tmux-utf8-launcher.test.py` pasa dos pruebas: instalación
en HOME temporal/argumentos/stdin y cliente tmux real por PTY con LC_ALL=C,
client_utf8=1 y captura íntegra de áéíóú ñ ¿ ¡. `bash -n` y `git diff --check` pasan.
La prueba amplia server-installer.bats.sh falla en el mismo commit base y en
esta rama por una aserción previa de `netns` ausente en Starship. La prueba amplia
server-terminal.bats.sh llega al fallback de bun real de este host y agota su
límite de 15 s; no se declara pasada ni se continúa con instaladores reales.

Fifrex pendiente: `aj@server.fifrex.com` (SSH directo y Cloudflare) y su dirección
Tailscale no respondieron. Tailscale lo marca offline desde unas 17 h antes de
la inspección. No se usó ni guardó la contraseña temporal. No se ejecutó paru ni
se modificó Fifrex. Usuario avisado por agent-push y pregunta pendiente en chat.
Siguiente acción: conectar el host o recibir ruta/puerto SSH vigente; leer sus
instrucciones y estado, respaldar lo afectado y actualizar allí el proyecto
correspondiente y Arch con paru. No trasladar secretos ni registros DNS de ORGM.
