# Restaurar tmux y agentes al encender

Los perfiles NixOS que seleccionan `tmux` instalan `tmux-session`, activan
`linger` para su usuario y arrancan `tmux-session.service` con `default.target`.
No hace falta abrir el escritorio ni una terminal. El timer guarda cada minuto,
incluso sin clientes conectados, y el servicio guarda de nuevo al apagarse.
Resurrect conserva sesiones, ventanas, paneles, carpetas y contenido visible.
`C-a S` guarda y `C-a R` restaura con la configuración personal de Osmarg/Jarq.

```sh
tmux attach                       # conectarse al trabajo restaurado
tmux list-sessions
tmux-session save                 # guardar ahora
systemctl --user status tmux-session.service tmux-session-save.timer
journalctl --user -u tmux-session -u tmux-session-save
```

El hook de guardado identifica la conversación del proceso que ocupa cada
panel y sustituye su comando por la reanudación propia de su cliente:

| Cliente | Reanudación |
| --- | --- |
| Codex | `codex resume UUID` |
| Claude Code | `claude --resume UUID` |
| Pi | `pi --session /ruta/session.jsonl` |
| OMP | `omp --resume /ruta/session.jsonl` |
| OpenCode | `opencode --session ses_ID`; el plugin envía la continuación al mismo ID |

Guarda el ID o archivo exacto: dos paneles en la misma carpeta pueden tener historias
distintas. Al restaurar envía un mensaje para revisar el estado real y continuar
la última tarea autorizada; si ya terminó, se pausó o necesita información,
el agente debe esperar. Se mantienen los controles de cada cliente y sus
opciones de modelo, perfil y permisos reconocidas por el helper.

Para restaurar las conversaciones esperando tu intervención, cambia en
`~/.config/tmux/persistence.conf`:

```tmux
set -g @orgm-agent-auto-continue off
```

Aplica la preferencia con `tmux source-file ~/.tmux.conf`. El arranque automático
no garantiza que un agente pueda avanzar: necesita sus credenciales vigentes,
red y los archivos del proyecto disponibles. Después de un corte de corriente
se recupera el último guardado, normalmente de hace menos de un minuto.

## Instalación y actualización

Los scripts se empaquetan en Nix; la configuración de tmux sigue siendo una
copia editable. Para aplicar los cambios del checkout:

```sh
sudo nixos-rebuild switch --flake path:.#orgm  # elegir el host correspondiente
orgm-dot pull tmux                       # respalda antes de reemplazar
orgm-dot pull ai-tools                   # launchers de los agentes
tmux source-file ~/.tmux.conf
systemctl --user start tmux-session.service tmux-session-save.timer
```

El cargador usa las rutas de plugins del paquete Nix, que permanecen válidas
durante su generación; no depende de enlaces en `/run/current-system/sw/share`.
El instalador portable `server/install.sh` copia estos mismos scripts a
`~/.local/lib/orgm-tmux/` y usa plugins locales y unidades de `systemd --user`,
sin necesitar Nix. Su instalación normal en Arch/Ubuntu habilita `linger` y el
arranque de tmux; `--no-autostart` prepara los archivos y `--home DIR` nunca
activa servicios en un HOME ajeno. Véase [el instalador portable](../server/README.md#restauración-al-encender-y-agentes).

## Sesiones que ya estaban abiertas

El wrapper de Codex inicia las nuevas interfaces dentro de tmux con
`--no-daemon`: cada panel tiene un backend propio y su archivo de conversación
puede identificarse por el árbol de procesos. Esto evita atribuirle a un panel
las conversaciones de otros paneles que comparten el daemon.

Para una interfaz de Codex que ya usaba el daemon compartido, obtén su UUID con
`/status` y asócialo una sola vez desde otra terminal:

```sh
tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_id}'
tmux-agent-resume bind codex UUID %0
tmux-session save
```

La asociación caduca al cambiar el proceso; después de `/new` o `/resume` en
esa interfaz antigua, vuelve a asociar el ID. Los agentes nuevos con backend
propio se detectan en cada guardado. Claude se identifica por su registro de
sesión o el archivo de depuración abierto. Si no puede determinarse un UUID
exacto, se restaura un shell y se registra el motivo; no se elige arbitrariamente
la última conversación de la carpeta.

Los launchers `~/.local/bin/pi`, `omp` y `opencode` añaden el registrador solo
cuando se abre su interfaz dentro de tmux. Pi y OMP cargan una extensión
explícita, incluso con `-ne`/`--no-extensions`; conserva las demás preferencias.
La extensión actualiza el archivo exacto después de iniciar, cambiar o bifurcar
una sesión, y excluye subagentes. OpenCode 1.4.3 usa un plugin de TUI que observa
la conversación seleccionada, incluso si cambias de sesión sin enviar mensajes.
Su configuración temporal conserva el JSONC personalizado y los plugins previos.
El plugin envía la continuación al hilo restaurado una sola vez, cuando la
interfaz está lista; no depende de `--prompt`, que en OpenCode 1.4.3 solo se
envía automáticamente desde la pantalla de inicio. Al desactivar
`@orgm-agent-auto-continue` no se envía ningún mensaje.
Las interfaces deben abrirse con estos launchers para registrar su identidad.
Las sesiones efímeras (`--no-session`) no se pueden recuperar después del apagado.
La restauración de OpenCode cubre interfaces locales; `opencode attach` depende
de su servidor remoto y conserva el comportamiento de ese cliente.

Los metadatos de seguimiento están en `$XDG_RUNTIME_DIR/orgm-tmux-agents/`,
con PID, instante de inicio del proceso, socket y panel para rechazar registros
viejos. Los snapshots persistentes conservan solo los datos para reanudar.
Las conversaciones y credenciales permanecen en los almacenes de cada cliente.

Referencias: [sesiones de Pi](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/session.md),
[reanudar OMP](https://github.com/can1357/oh-my-pi/blob/main/docs/session-operations-export-share-fork-resume.md)
y [CLI de OpenCode](https://opencode.ai/docs/cli/).

Los snapshots anteriores siguen en `~/.tmux/resurrect/` (o el directorio definido
por `@resurrect-dir`). Un snapshot antiguo que solo guardaba `claude` o `codex`
sin UUID no permite reconstruir qué conversación pertenecía a cada panel.
