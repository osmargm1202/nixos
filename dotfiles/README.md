# Dotfiles editables con orgm-dot

La restauración automática de tmux y de conversaciones de Claude Code, Codex,
Pi, OMP y OpenCode
se documenta en [tmux y agentes](../docs/tmux-agents.md).

NixOS instala las aplicaciones, servicios y el helper Go `orgm-dot`. Las
configuraciones de este directorio se leen del checkout al ejecutar el helper;
no se importan en `home.file` ni se mantienen como enlaces al Nix store.
La primera activación copia los archivos ausentes y convierte los enlaces
antiguos al Store, con respaldo. Las activaciones siguientes respetan las
ediciones locales y los archivos que hayas eliminado.

```sh
orgm-dot                          # elegir aplicación y operación
orgm-dot list
orgm-dot list --all               # todos los nombres registrados en el repo
orgm-dot show waybar
orgm-dot add mi-app .config/mi-app
orgm-dot diff waybar
orgm-dot diff waybar --patch
orgm-dot pull waybar --dry-run
orgm-dot pull waybar              # repo → HOME
orgm-dot push waybar --dry-run
orgm-dot push waybar              # HOME → checkout
orgm-dot backups
orgm-dot restore ID
orgm-dot remove mi-app --dry-run
orgm-dot remove mi-app            # retirar solo este usuario/equipo/perfil
```

`pull` reemplaza completamente cada ruta seleccionada: desaparece cualquier
archivo local de esa ruta que no esté en la copia del repo. `push` reemplaza
completamente el snapshot de esa aplicación y contexto dentro del checkout,
incluyendo archivos nuevos y eliminaciones. Ambos respaldan antes de escribir.
Los archivos de las otras aplicaciones permanecen intactos. Cierra la aplicación
antes de reemplazar su configuración para que no vuelva a guardar datos viejos.
El helper no reinicia programas ni el escritorio.

`diff` compara las rutas registradas: `A` existe solo en el repo, `D` existe
solo en HOME y `M` difiere en contenido, tipo o permiso ejecutable. `--patch`
muestra las diferencias de texto; `--json` entrega el listado para otros tools.
`--dry-run` compara sin reemplazar archivos. Los respaldos se guardan en
`~/.local/state/orgm-dot/backups/`; una restauración genera otro respaldo.
No hay limpieza automática de respaldos.

`list` muestra los grupos que tienen una configuración disponible en el repo o
en HOME para el contexto actual. Estos nombres son identificadores de dotfiles,
no una lista de paquetes instalados: `ai-tools`, `orgm-shell` y `desktop-tools`,
por ejemplo, reúnen varios archivos o helpers. `list --all` incluye todos los
nombres registrados, incluso los de otros perfiles y los retirados. `show APP`
devuelve su JSON, rutas seleccionadas, ubicación del snapshot y `disabled`.

`push` guarda en el repositorio **local**. Para publicarlo en GitHub:

```sh
git add -A -- dotfiles/apps/waybar
git diff --cached -- dotfiles/apps/waybar
git commit --only -m 'Update Waybar dotfiles' -- dotfiles/apps/waybar
git push
```

Para traer cambios publicados, actualiza el checkout con Git y ejecuta
`orgm-dot diff APP` / `orgm-dot pull APP` solo para las aplicaciones que quieras
aplicar. Un `git pull` o un rebuild no reemplaza las configuraciones activas.

## Un JSON por aplicación

`apps/waybar.json`, por ejemplo, registra las carpetas y archivos exclusivos:

```json
{
  "version": 1,
  "name": "waybar",
  "paths": [
    ".config/waybar-hypr",
    ".config/waybar",
    ".local/bin/waybar-watch"
  ]
}
```

Las rutas son relativas a HOME. Se pueden registrar varias carpetas y archivos
sueltos; nunca una carpeta compartida completa como `.config`, `.local/bin`,
`.local/share/icons` o `.local/share/applications`. Sus elementos se registran
por separado. El helper rechaza rutas superpuestas entre aplicaciones,
traversal, solapamientos con su estado/checkout y escrituras a través de enlaces
de directorio. Los enlaces relativos internos de un snapshot se conservan;
los enlaces externos se rechazan. Los enlaces antiguos al Store se materializan
como datos editables. Los enlaces entre capas del repo también se copian como
archivos reales, como el tema Rofi compartido de i3.

Las rutas que tienen contenido para el usuario/equipo/perfil seleccionado son
las únicas que se aplican desde las capas iniciales. `push` también puede guardar
rutas locales registradas que aún no tienen una copia en el repo. Para añadir
una aplicación nueva basta crear `apps/NOMBRE.json`, registrar sus rutas y
hacer `orgm-dot push NOMBRE`; no necesita una declaración Nix ni un seed previo.
El comando `add` crea ese JSON por ti:

```sh
orgm-dot add mi-app .config/mi-app .local/bin/mi-app-helper
orgm-dot show mi-app
orgm-dot push mi-app
```

Se indican rutas relativas a HOME, respetando mayúsculas. `add` solo registra;
`push` guarda después la copia completa. No instala el programa. Rechaza nombres
duplicados, rutas compartidas o rutas pertenecientes a otro grupo.

Para dejar de guardar una aplicación en este contexto:

```sh
orgm-dot show mi-app
orgm-dot remove mi-app --dry-run
orgm-dot remove mi-app
```

`remove` conserva la configuración local y los snapshots de otros usuarios,
equipos y perfiles. Respalda y retira el snapshot actual, y escribe
`apps/mi-app/USUARIO/EQUIPO/PERFIL/removed.json` para que futuras activaciones no
vuelvan a copiarlo. El registro global `apps/mi-app.json` y las plantillas
iniciales de `config/` se conservan porque pueden usarse en otros equipos.
`push`, `pull` y `diff` quedan deshabilitados para ese grupo en este contexto;
`show` y `list --all` permiten consultarlo. Para recuperar el seguimiento y la
copia anterior, usa `orgm-dot restore ID` con el respaldo que imprime `remove`.
La retirada se publica en GitHub mediante Git, igual que los demás cambios del
checkout; no se hace un commit ni un push de Git automáticamente.

`ryoku-hub` guarda `desktop.json` y `shell.json` del Hub mediante este mecanismo,
sin copiar el directorio nativo completo. Un `pull` sin snapshot ni contenido de
origen falla, conservando los datos locales. Los snapshots se guardan así:

```
apps/waybar/osmarg/envy/hyprland/
  snapshot.json
  home/.config/waybar-hypr/...
  home/.local/bin/waybar-watch
```

`snapshot.json` registra las rutas activas, las eliminaciones completas y los
directorios, incluidos los vacíos que Git no guarda. Si existe un snapshot se
usa completo, sin mezclar archivos de capas inferiores que resuciten borrados.
Cada operación prepara todas las copias antes de cambiar destinos. El reemplazo
de cada ruta usa renames y revierte los cambios anteriores si una instalación
posterior falla. Un corte de energía entre rutas se recupera con el respaldo.

## Configuraciones existentes y perfiles

Antes del primer `push`, se compone la configuración existente de `config/`,
en el mismo orden que antes: programas, perfil, usuario común, programas del
usuario, perfil del usuario, equipo compartido y perfil del equipo. La última
capa tiene prioridad. Así se conserva lo que ya tenía cada equipo sin duplicar
todo el árbol durante esta migración. Los snapshots posteriores son copias
completas por aplicación, usuario, equipo y perfil.

Envy, Lenovo y ORGM conservan Ryoku mientras se prueban las copias. El perfil
Hyprland alternativo queda preparado con paquetes oficiales, sin activarlo. Ryoku
conserva su materializador, ajustes del Hub, configuración gráfica y recursos
nativos. El helper aporta las preferencias y módulos personales; Bash y Kitty
usan sus archivos de usuario, sin reemplazar sus directorios nativos completos.
La migración no cambia el escritorio de Envy ni impone la configuración del
perfil Hyprland sobre Ryoku.

El contexto declarativo está en `/etc/orgm-dot/context.json`. La activación de
usuario también instala el binario en `~/.local/bin/orgm-dot` y metadatos en
`~/.local/state/orgm-dot/context.json`, que el CLI usa cuando el contexto del
sistema aún no está instalado. Esto permite probar las copias sin cambiar el
sistema global. La ubicación del checkout se configura con `orgm.dotfiles.repository`, por defecto
`/home/USUARIO/Hobby/nixos`. Debe existir en el equipo antes de la primera
activación. Se puede sobrescribir para una operación con `--repo RUTA` o
`ORGM_DOT_REPO`. Para pruebas/otros contextos se admiten `--context JSON`,
`--home`, `--host`, `--profile`, `--user` y `--state` (dentro del HOME indicado).

Las unidades systemd, integración PAM, metadatos del runtime y referencias a
paquetes siguen perteneciendo a NixOS/Home Manager. La configuración personal
de Git está en `config/users/osmarg/programs/git/.config/git/config` y queda
editable, permitiendo `gh auth setup-git` sin modificar el Store.

## Historial recuperado

El Go anterior estaba en `cmd/orgm-dot` e `internal/dot*`, ya presente en
[la importación del 26 de mayo de 2026](https://github.com/osmargm1202/nixos/commit/4c7a0f7).
Tenía `sync`, `diff`, host, listado global de rutas y daemon. Se reemplazó por
[Home Manager el 15 de junio](https://github.com/osmargm1202/nixos/commit/2392e59)
y se retiró el código muerto
[el 6 de julio](https://github.com/osmargm1202/nixos/commit/38603b2).
También se revisó el repositorio anterior `dotfiles` en mayo y abril; su
[configuración del 17 de mayo](https://github.com/osmargm1202/dotfiles/blob/506603c5e964ccd832d8a94f3e3308af0c88b103/config/dotfiles.json)
usaba listas shared/host. Esta versión recupera el flujo de copias y diff,
con manifiestos por aplicación, snapshots completos, respaldo y restauración.

El código Go está en `nixos/orgm/orgm-dot-src`, sin dependencias externas.
`go test ./...` allí verifica los reemplazos, diff, permisos, enlaces, respaldo,
rollback y aislamiento. `python3 tests/dotfiles-copies.py` verifica los cinco
equipos, el CLI real, Hyprland y el materializador de Ryoku sin tocar HOME real.
