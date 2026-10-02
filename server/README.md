# Terminal ORGM para servidores

`server/install.sh` replica Bash y tmux por usuario en Ubuntu/Debian y Arch.
Es independiente del `install.sh` de la raíz, que instala/configura NixOS.
El checkout real de este equipo está en `~/Hobby/nixos`, no en `~/Code/nixos`.

## Qué se comparte

- `server/dotfiles/.bashrc` y `~/.config/bash/terminal.bash`: historial,
  prompt, aliases, navegación, rutas de herramientas e integración opcional
  con Starship, Zoxide, Atuin, fnm, Eza y neofetch.
- Funciones `codex` y `claude` con los permisos de los lanzadores de NixOS,
  y `omp` con resolución de sus assets cuando se instala con Bun.
- Comandos `codex-install`, `claude-install`, `omp-install` y sus variantes
  `*-update`, junto con `bun-install`, `blesh-install` y `blesh-update`.
  Se instalan los helpers; los binarios se descargan cuando se invocan.
- La misma `.blerc` de NixOS: edición Emacs, sugerencias de comandos/historial
  y separador entre comandos. Detecta ble.sh local o de `/usr/share/blesh`
  (incluidos paquetes de Arch); FZF añade atajos y previews de texto para SSH.
- El mismo `starship.toml` de NixOS, que se utiliza si Starship está instalado.
  Sus iconos requieren una Nerd Font en el terminal del dispositivo cliente.
- Neofetch automático solo en terminales interactivas, fuera de tmux,
  sin redirección y una vez por shell. El comando manual sigue disponible.
- `dotfiles/config/users/osmarg/programs/tmux/.tmux.conf`: la misma configuración del escritorio:
  Ctrl-a, mouse, copia vi, tema, atajos y fecha española. La opción
  `extended-keys-format` se configura únicamente si el tmux instalado la admite.
- `tmux-resurrect` y `tmux-continuum`: descargas HTTPS fijadas a commits,
  sin TPM ni rutas `/nix/store` en los servidores.
- `~/.bashrc.local`: archivo opcional para ajustes privados de cada host;
  el instalador no lo modifica. No se replican rutas de Villarpando, zona horaria,
  credenciales, claves SOPS ni configuraciones gráficas.

No cambia Fish, el shell de login, servicios, firewall, DNS ni NixOS.
Rechaza destinos gestionados por Nix/Home Manager: en el escritorio se debe
seguir usando Home Manager, no este instalador.

## Uso en el servidor destino

Desde un checkout que incluya estos archivos:

```bash
bash server/install.sh --source "$PWD" --dry-run --no-plugins
bash server/install.sh --source "$PWD"
# Herramientas nativas adicionales, con sudo cuando sea necesario:
bash server/install.sh --source "$PWD" --packages
# Copiar solo tmux sin reemplazar Bash:
bash server/install.sh --source "$PWD" --tmux-only
```

`--no-plugins` instala tmux básico y un loader vacío; si antes había plugins,
respalda y sustituye su loader, sin borrar sus directorios de datos.
`--home DIR` permite instalar en un HOME aislado. `--help` lista las opciones.
El modo `--dry-run` puede descargar/stagear archivos temporales, pero no modifica
el HOME ni instala paquetes.

El instalador muestra el destino y cinco etapas desde que comienza: preparación,
obtención de archivos/plugins, comprobación de destinos, dependencias y aplicación
de la configuración. Anuncia cada descarga antes de iniciarla y al completarla;
en una terminal muestra además una barra de progreso. Informa de los respaldos y
de las etapas omitidas por las opciones elegidas. Si una operación falla, indica
la etapa y termina sin anunciar éxito. Las descargas tienen límite de conexión
de 15 segundos, de duración total de 5 minutos y de inactividad de 30 segundos.

`--packages` instala tmux, git, curl, bash-completion, neovim, ripgrep,
fd-find/fd, fzf, zoxide, btop, jq, rsync, bat, file, tree, unzip y xz.
Los helpers para Bun, ble.sh y los agentes se ejecutan por separado; no instala
Starship, Atuin ni neofetch. Las versiones dependen de la distro;
replicar estos dotfiles no garantiza versiones de paquetes idénticas.
Arch utiliza `pacman -S --needed`, nunca `pacman -Sy`; si sus repositorios locales
están desactualizados, primero debe resolverse la actualización normal del sistema.
No se hace un upgrade completo de servidores automáticamente.

Todos los recursos se descargan antes de reemplazar configuraciones.
Los archivos cambiados, incluidos symlinks, se respaldan en:

```text
~/.local/share/orgm-dotfiles/backups/<fecha-hora-pid>/
```

Una reinstalación idéntica no crea nuevos respaldos. Los perfiles de login de
Bash conservan su contenido; si no cargan `.bashrc`, se añade un bloque con respaldo.
La `.bashrc` anterior **se sustituye**: trasladar sus particularidades deseadas
al archivo `.bashrc.local` desde el respaldo. Los comandos ya presentes en
`.profile`/`.bash_profile`, por ejemplo banners, no se eliminan automáticamente.

Abrir una nueva sesión Bash para aplicar los cambios. Para sesiones tmux existentes:

```bash
tmux source-file ~/.tmux.conf
```

En `server.or-gm.com`, cuyo login es Fish, esto configura Bash pero no lo convierte
en el shell de login. Entrar con `bash` para usar la configuración de Bash.

## Instalar las herramientas de terminal y desarrollo

Después de instalar los dotfiles y las dependencias con `--packages`:

```bash
exec bash
bun-install
blesh-install
codex-install
claude-install
omp-install
exec bash
```

Ejecutar los helpers con el usuario que utilizará los agentes. Bun y los paquetes
se instalan en HOME; no requieren `sudo`. `bun-install` usa el instalador oficial
sin añadir bloques a Fish ni a los perfiles de Bash. `blesh-install` descarga el
nightly oficial precompilado, instala en `~/.local/share/blesh` y no requiere make
ni gawk. El segundo `exec bash` carga el editor de línea recién instalado.

Los instaladores de agentes prefieren Bun. Codex también admite npm/pnpm con
prefijo de usuario; Claude usa su instalador nativo si no encuentra Bun, para
funcionar también en Ubuntu sin Node reciente. OMP requiere Bun (actualmente
1.3.14 o superior según upstream). `*-update` repite la instalación de la última
versión; `blesh-update` vuelve a descargar el nightly. Sus descargas no están
fijadas a una revisión y requieren conexión a Internet.

`codex` añade `--dangerously-bypass-approvals-and-sandbox` y `claude` añade
`--dangerously-skip-permissions` al iniciar conversaciones. Estos permisos son
los del usuario que ejecuta el agente; no conceden root. Comandos administrativos
como `codex login`, `codex remote-control pair`, `claude auth` y
`claude remote-control` conservan sus argumentos originales. Para ejecutar
directamente el CLI con sus permisos habituales, usar `command codex ...` o
`command claude ...`. Las cuentas se autentican en cada servidor; este instalador
no copia sesiones ni credenciales desde NixOS.

Las rutas `~/.local/bin`, Bun, npm, pnpm, Cargo, Go y OpenCode se incorporan sin
duplicarse al recargar Bash. Los módulos del instalador se leen desde
`~/.config/bash`, incluso si el host utiliza un `XDG_CONFIG_HOME` diferente.

Con ble.sh + FZF están disponibles los atajos de Emacs de NixOS:

| Atajo | Acción | Dependencia adicional |
| --- | --- | --- |
| Alt+R | Historial con FZF | — |
| Alt+F | Insertar un archivo con preview | fd/fdfind |
| Alt+C | Cambiar de directorio con preview | fd/fdfind |
| Alt+P | Buscar procesos | pgrep |
| Alt+A | Traducir la línea a un comando | aichat, si está instalado |

`switch-preview` y `dir-preview` funcionan sin escritorio, con Bat/Tree/Eza si
están disponibles y alternativas con herramientas básicas. Se conservan `gst`,
`gdiff`, `gp`, `ta`, `tn`, `back-op`, `backtrack-op`, `za` si existe Zellij y
`cheat` si hay Curl/FZF/Bat. Las funciones de NixOS, Flatpak, emuladores y apertura
de páginas en un escritorio no se trasladan al servidor.

Fuentes de los instaladores:
[Codex](https://learn.chatgpt.com/docs/developer-commands),
[Claude Code](https://code.claude.com/docs/en/setup),
[OMP](https://github.com/can1357/oh-my-pi),
[ble.sh](https://github.com/akinomyoga/ble.sh#quick-instructions).

## Win+D: SSH directamente en tmux

Los selectores de i3 y Hyprland abren Kitty con `ssh -t <destino> 'tmux attach'`.
No dependen del alias remoto `ta` ni de que el shell remoto sea Bash.
Se conectan a una sesión existente; no crean una nueva si no hay sesiones.

La lista muestra primero los últimos destinos seleccionados, de más reciente a
menos reciente; los servidores sin historial quedan después en orden alfabético.
El historial es compartido entre ambos perfiles y persiste en
`${XDG_STATE_HOME:-~/.local/state}/orgm-ssh-host/recent-hosts`.
Cada selección promueve el servidor, incluso si la conexión luego falla.
Se conserva una sola entrada por host/puerto, con el último usuario elegido.

También se puede escribir `usuario@servidor`; ese destino queda recordado.
Los destinos `[host]:puerto` y `usuario@[host]:puerto` conservan su puerto.
En Hyprland, un destino que ya incluye usuario evita el paso de elegirlo otra vez.
Eliminar un known host desde ese selector también limpia su historial reciente.

## Publicación en custom.or-gm.com/install

Primero publicar estos cambios en `osmargm1202/nixos`, rama `master`.
Después crear DNS proxied y una regla de redirect HTTPS exacta:

```text
Host: custom.or-gm.com
Path: /install
Status: 302 o 307
Location: https://raw.githubusercontent.com/osmargm1202/nixos/master/server/install.sh
```

La regla no debe reenviar los otros paths a servicios privados. DNS solo no hace
una redirección HTTP. Cloudflare permite servir este redirect sin añadir un
servidor de aplicación ni abrir puertos.
Una vez publicado y verificado:

```bash
curl -fL https://custom.or-gm.com/install -o /tmp/orgm-dotfiles-install.sh
# Revisar el archivo antes de ejecutarlo. No ejecutar todo el script con sudo.
bash /tmp/orgm-dotfiles-install.sh --dry-run --no-plugins
bash /tmp/orgm-dotfiles-install.sh --packages
```

Por defecto los dotfiles se obtienen de `master`. Para una revisión inmutable,
usar el mismo commit tanto para el script como para sus recursos:

```bash
export ORGM_DOTFILES_BASE_URL="https://raw.githubusercontent.com/osmargm1202/nixos/$REV"
curl -fL "$ORGM_DOTFILES_BASE_URL/server/install.sh" -o /tmp/orgm-dotfiles-install.sh
bash /tmp/orgm-dotfiles-install.sh
```

`REV` debe ser el commit publicado elegido. Validar DNS, certificado HTTPS,
respuesta redirect y descarga final antes de anunciar el endpoint como operativo.

## Decisión: paquetes nativos ahora, Nix opcional

Revisión del 30 de septiembre de 2026:

| Servidor | Sistema / shell de login | Disco raíz | Nix |
| --- | --- | --- | --- |
| `osmarg@server.slci.stream` | Ubuntu 24.04 / Bash | 14 % usado, 251 GB libres | No instalado |
| `osmar@nextcloud.or-gm.com` | Ubuntu 24.04 / Bash | 95 % usado, 46 GB libres | No instalado |
| `osmarg@server.or-gm.com` | Arch / Fish | 66 % usado, 77 GB libres | No instalado |

En `slci` no había archivo de configuración tmux: se copió la configuración local
al servidor. Se corrigió únicamente el arranque automático de neofetch en su
`.bashrc`, conservando sus ajustes de host; respaldo:
`~/.bashrc.before-orgm-tmux-20260930`. No se desplegaron dotfiles ni paquetes en los
otros dos servidores. Nextcloud tiene además neofetch incondicional en `.profile`;
el instalador conserva ese perfil y no elimina ese banner ajeno a `.bashrc`.

Para este alcance, Bash + paquetes nativos evita un segundo gestor y un daemon.
Nix es viable en Ubuntu/Arch **sin migrar a NixOS**. Con Home Manager standalone
aporta dotfiles declarativos, versiones de herramientas fijadas mediante lock y
generaciones para rollback. A cambio requiere instalación/integración de Nix,
`/nix/store`, gestión de generaciones/GC y cuidado adicional con Fish y PATH.
El rollback de Home Manager no revierte servicios, datos, apt ni pacman.
No añadir Nix a Nextcloud con el disco ya al 95 %.

Si se necesitan versiones exactamente iguales y rollback de herramientas,
probar Nix + Home Manager standalone primero en `slci`, manteniendo los servicios
nativos. El instalador actual no lo instala automáticamente.

Referencias oficiales:
- [Instalación Nix; multi-user recomendado en Linux](https://nix.dev/install-nix.html).
- [Home Manager standalone e integración de shell](https://nix-community.github.io/home-manager/installation/standalone.html).
- [Generaciones y rollback de Home Manager](https://nix-community.github.io/home-manager/usage/rollbacks.html).

## Verificación realizada

- `bash tests/server-bash-banner.bats.sh`: terminal con banner, tmux sin banner,
  invocación manual, recarga, redirección y ejecución no interactiva.
- `bash tests/server-installer.bats.sh`: dry-run, fallo de staging sin modificar
  dotfiles, respaldo de symlink, perfil de login preservado, idempotencia,
  helpers ejecutables, rechazo de destinos Nix y tmux-only.
- `bash tests/server-terminal.bats.sh`: flags de permisos, subcomandos de login
  y acceso remoto, stdin preservado, instaladores con gestores simulados,
  prefijos de usuario, fallback nativo de Claude, descargas fallidas, assets de
  OMP, rutas sin duplicados, navegación y previews.
- Instalación real de Bun 1.4.2 y ble.sh nightly en HOME temporal; perfiles
  conservados, carga en PTY interactiva, Emacs, sugerencias y widgets de FZF
  verificados también con un `XDG_CONFIG_HOME` diferente.
- Descarga e instalación standalone mediante un servidor HTTPS local de prueba;
  primer perfil Bash e instalación repetida verificados.
- Instalación tmux-only real en `slci`, recarga sin perder `slc-manage`, atajos S/R
  de plugins y guardado real de una sesión de prueba con resurrect, en socket aislado.
- Opción de extended keys verificada en tmux 3.4 remoto y en tmux local reciente.
- Planes `--dry-run --packages` ejecutados en Ubuntu y Arch, sin modificar sus HOME.
  No se ejecutó una instalación de paquetes ni se publicó el dominio.
