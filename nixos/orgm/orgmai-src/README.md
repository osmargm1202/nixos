# orgmai / ai-chat

Lanzador Go para elegir Claude, Codex, OpenCode, OMP o Pi. Sustituye su proceso
con el ejecutable nativo y conserva la entrada/salida del terminal. Solo guarda
el programa elegido en `~/.config/orgmai/config.json` (0600).

```sh
orgmai                 # primera vez: elegir programa; después: ejecución nativa
orgmai new             # ejecución nativa, usado por Super+A
orgmai prev            # historial del programa, usado por Super+Shift+A
orgmai program         # cambiar programa, usado por Super+Ctrl+Shift+A
```

`ai-chat` es un alias del mismo binario; `config` es un alias de `program`.
Los atajos existentes abren Kitty con clases que el escritorio coloca flotantes
y centradas. El lanzador no abre otra terminal dentro de Kitty.

Pi recibe `-ne --no-mcp --no-skills --no-themes --use-theme dark`. Usa sus propios modelos,
credenciales y sesiones, con la interfaz nativa y sin recursos externos.
La preferencia nativa `quietStartup: true` oculta el encabezado y los detalles
de inicio; el tema interno oscuro evita cargar el tema personalizado durante
el arranque de OrgM AI, sin cambiar el tema guardado. La preferencia se guarda en `~/.pi/agent/settings.json` (app `pi` de orgm-dot). El lanzador no implementa RPC, peticiones de IA, un
prompt, un selector de modelos ni conversaciones propias. Se ignoran los campos
antiguos `provider`, `model` y `thinking`; no se eliminan archivos de historial
antiguos ni se modifican los ajustes del cliente.

Los demás argumentos se pasan literalmente al ejecutable. `new` y `chat` se
retiran como alias del lanzador. `prev` añade `--resume` para Pi/Claude/OMP,
`resume` para Codex o `--continue` para OpenCode; el cliente maneja el historial.

Los clientes se instalan por separado. El selector identifica programas ausentes
y encuentra instalaciones de Bun, npm, FNM, PNPM y `~/.opencode/bin`, además de
PATH. Los shortcuts personales de Claude/Codex no cuentan como una instalación.

`go test ./...` y `go vet ./...` verifican selección/cancelación, compatibilidad
de la elección guardada, ejecución real con stdin, Pi sin extensiones/MCP/skills/temas y sin los
overrides antiguos, intérpretes FNM y conservación de credenciales/configuración.
