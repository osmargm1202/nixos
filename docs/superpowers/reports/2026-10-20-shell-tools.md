# Integraciones de terminal después de Ryoku — 2026-10-20

## Goal

Resolver `z`/`zi: command not found` y revisar las herramientas de terminal
seleccionadas por osmarg en orgm/Hyprland.

## Instructions

Aplicar nosotros, conservar secretos/historiales/configuración personal, sin
rebuild/switch, activación global de Home Manager, reboot, commit ni push.
No instalar indiscriminadamente herramientas opcionales no seleccionadas.

## Discoveries

- Zoxide 0.9.9 sí estaba instalado. La `.bashrc` activa seguía siendo el
  bootstrap de Ryoku del 17 de octubre, que importa `bash/ryoku.bash`.
  Este ejecuta `zoxide init bash --cmd cd`: crea `cd`/`cdi`, no `z`/`zi`.
  El `orgm-shell/workflows.bash` local tampoco tenía los wrappers posteriores.
- La configuración estándar del repositorio ya inicializa zoxide como `z`/`zi`.
  La prueba privada con `orgm-dot pull bash` demostró que el fallo principal
  era **configuración local antigua**, no falta del paquete.
- `.blerc` activa era también la mínima de Ryoku, no la configuración estándar
  de widgets/atajos. La configuración estándar importaba las teclas de FZF,
  pero faltaba su módulo independiente de completion: `_fzf_complete` ausente.
- Faltaba el ejecutable `file`, requerido por `switch-preview` para distinguir
  imágenes de texto. Se declara con el grupo `shell` en `nixos/common.nix`.
- Blesh omite deliberadamente su carga en `bash -ic` con
  `BASH_EXECUTION_STRING`. No interpretar esas funciones ausentes como un fallo
  del REPL: se añadió una prueba con Bash interactivo real y PTY controlador.
- Atuin en esta versión de Blesh puede usar macros para Ctrl+R, no un widget
  con nombre. La prueba compara la binding real de Atuin antes/después.

## Accomplished

- RED real inicial: z/zi ausentes, navegación falla con exit31.
- RED de regresiones: falta `_fzf_complete`; evaluación correcta de paquetes
  HM demuestra que falta `file`. GREEN tras dos arreglos mínimos: importar
  `contrib/integration/fzf-completion` en `.blerc` base/osmarg/jarq y declarar file.
- `tests/shell-tools.test.py`: dos casos pasan. Navegación real z/zi con
  espacios y DB privada, selección con FZF real y filtro determinista,
  widgets Alt+R/F/C/P/A, Ctrl+R de Atuin, reload estable y Bash no interactivo
  sin funciones. No hay llamadas a servicios AI ni cambios a historiales reales.
- `tests/shell-tools-session.test.py`: REPL real en PTY privado pasa Blesh,
  completion FZF, atajos personales, Atuin y z/zi. No sustituye una prueba
  visual de cada aplicación; no modifica la terminal del usuario.
- Pasan también `bash-blesh-emacs.bats.sh`, `session-path-dedupe.bats.sh`,
  `omp-package-dir.bats.sh`, `sops-age-key.bats.sh`, `server-terminal.bats.sh`
  y `git diff --check`. No se repite ni se declara verde toda la suite general.
- Revisión independiente: sin hallazgos accionables; volvió a ejecutar los
  dos casos, la compatibilidad Blesh y el REPL nativo con resultado correcto.
- Se copiaron solo ocho archivos propios al checkout principal, con comparación
  de contenidos base/ausencia de destinos nuevos. No se alteraron los cambios
  previos de ScrollOverview o Syncthing. Se repitieron las pruebas desde allí.
- `orgm-dot pull bash` aplicado por el asistente. Backup del helper:
  20261021T002302.071436460-bash-pull.
  Preimagen privada adicional: `/home/osmarg/.local/state/orgm-shell-repair/20261021T002302Z`.
  Los cuatro archivos locales extra `private-env.bash`, `rashin.bash`,
  `ryoku.bash` y `user.bash` se restauraron byte por byte después del pull.
  **No se vuelven a importar los arranques antiguos ni se suben secretos al repo.**
  `orgm-dot diff bash` muestra únicamente esos cuatro D conservados a propósito.
- File 5.47 realizado desde el pin NixOS existente, GC-root
  `~/.local/state/orgm-shell-tools/file`; `~/.local/bin/file` apunta a su binario.
  No se sobrescribió otro ejecutable. La declaración Nix sirve para futuras
  activaciones; el enlace permite usarlo ahora sin cambiar la generación.
- Vistas previas reales de texto/directorio/PNG/ZIP pasan, incluidas rutas con
  espacios. PNG utiliza su detección MIME y Chafa; no se confunde con texto.

## Inventario revisado y límites

Disponibilidad de comandos seleccionados verificada: wget/curl/rsync/vim,
fzf/zoxide/Starship/Atuin, eza/bat/fd/rg/file/jq, git/git-lfs, tmux/zellij,
Kitty, age/SOPS, trash, zip/unzip/unrar, btop/spf/ncdu/fastfetch, just/figlet/
termdown/nix-search-tv/ns, xclip/wl-copy/wl-paste, uv/Node/npm/Bun, gh/aichat,
lsd/chafa/ouch y helpers de preview. Ninguno falta tras la reparación.
Aliases y funciones útiles (gst/gdiff, ta/tn, nixg/nixclean, omp, sops-age-key)
se cargan en el Bash aplicado. No se ejecutan operaciones destructivas, AI
remota, sesiones multiplexer reales ni sincronización de cuentas para probarlos.

`mise`, `direnv`, `fnm`, `yazi`, `tre`, `ftdv` y `delta` no están instalados
ni seleccionados como dependencias obligatorias de este perfil. No se añaden
por referencias antiguas u opcionales; `spf` es el gestor disponible. Git no
tenía pager ni diffFilter apuntando a delta. Esto es un inventario, no una
promesa de haber probado todas las aplicaciones/interacciones del usuario.

## Next Steps

- **Abrir una terminal nueva** para cargar la `.bashrc` corregida. Los procesos
  Bash ya abiertos conservan funciones/guardas y el estado de Blesh anterior;
  no se inyectó código ni se reiniciaron terminales con trabajos activos.
- En una próxima activación NixOS normal, `file` vendrá del perfil declarado;
  se podrá retirar el enlace/GC-root temporal cuando ese binario esté disponible.
- Un futuro pull completo de Bash vuelve a reemplazar su directorio: recordar
  preservar los archivos locales privados; no hacer push de ellos al repo.
- Sin commit/push solicitado para esta tarea.

## Relevant Files

- `.blerc` base y usuarios — completion FZF compatible con Blesh.
- `nixos/common.nix` — dependencia file para previews.
- `tests/shell-tools*.test.py` — regresiones reales y REPL en PTY privado.
- `tests/bash-blesh-emacs.bats.sh` — ambas imports en API moderna/estable.
- `~/.bashrc`, `~/.blerc`, `~/.config/bash/` — perfil estándar aplicado.
