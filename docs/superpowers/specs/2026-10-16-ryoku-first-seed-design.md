# Ryoku: preferencias iniciales y propiedad posterior del usuario

Estado: **aprobado por el usuario (dale); implementación en revisión, sin activación**.
Petición: Osmarg quiere sus preferencias como punto de partida, pero después
configurarlas desde Ryoku sin que Nix/despliegues vuelvan a imponerlas.

## Objetivo y alcance

En los hosts Ryoku de Osmarg (`envy`, `lenovo`, `orgm`), el repositorio proporciona
valores iniciales cuando faltan los archivos y bibliotecas importables de sus
funciones. Después mandan los stores nativos del Hub y los archivos de usuario.
No crear variantes de flake, unir perfiles históricos ni alterar i3/Jarq.

Esto se refiere a **preferencias que Ryoku administra**, no a sustituir NixOS:
paquetes, drivers, servicios del sistema, seguridad, hardware, PAM, SDDM y secretos
siguen declarativos. Conservar Syncthing/Tailscale obligatorios y que el resto
del inicio de aplicaciones lo elija el usuario. No introducir credenciales.

## Hallazgos comprobados

Inspección SSH de Envy, solo lectura, 2026-10-16:

- `.bashrc` y los ficheros Bash personales son enlaces de Home Manager al Store.
  Se carga el arranque compartido anterior, no el arranque Bash de Ryoku.
- Faltan `bash/ryoku.bash`, `bash/rashin.bash`, `bash/user.bash` y el entorno
  `ryoku-terminal/env.sh`. El empaquetado Nix fijado no instala esos recursos,
  aunque existan en la fuente upstream.
- `~/.config/fastfetch/config.jsonc` es un archivo regular y editable. El usuario
  confirma que su vista previa del Hub cambia. **No sustituir ese archivo** para
  intentar corregir el arranque de la terminal.
- `prepare.sh` vuelve a instalar `hypr/user.lua`, el override de rebind, el hook
  Matugen y la preferencia de opacidad Kitty en cada preparación.
- Varios módulos personales que carga `user.lua` siguen siendo enlaces
  inmutables; convertir solo el entrypoint no basta para ceder su propiedad.
- `common-dotfiles.nix` excluye raíces administradas por Ryoku, pero no ofrece
  todavía un inventario de preferencias personales iniciales para ellas.
- El materializador Ryoku ya conserva Fastfetch y otros seeds cuando existen,
  dispone de stores nativos y de `ryoku/user_edits`. Hay que usar ese contrato,
  no congelar toda su base ni mantener una segunda configuración activa.

## Política de propiedad

| Elemento | Inicialización | Después |
|---|---|---|
| Fastfetch y logos personales | Copiar solo ficheros ausentes, antes del seed upstream | Hub/Fastfetch y archivos editables; nunca relink ni reset |
| `.bashrc` y `bash/user.bash` | Bootstrap editable de Ryoku y lista de imports personales | Usuario; no reinsertar imports que haya quitado |
| Bash de Ryoku, entorno y Rashin | Recursos de la versión fijada, entregados mediante su base nativa | Actualización de Ryoku y mecanismo nativo de overrides |
| Funciones y workflows de Osmarg | Bibliotecas separadas, importadas desde `user.bash` | Código importable actualizable; no imponer banner, tema o prompt |
| Preferencias Hyprland/Niri/Kitty/Matugen | Stores soportados o archivos/overrides nativos iniciales, según cada formato | Hub o archivo personal correspondiente; no reemplazo periódico por nuestro prepare |
| Módulos Lua personales cargados | Copias editables iniciales, no dependencias ocultas a enlaces de preferencias inmutables | Usuario; conservar comportamiento inicial y cambios posteriores |
| Artefactos derivados de stores | Generar desde el store vigente (p. ej., puente de ancho Hyprland) | No son una segunda fuente de preferencias ni un archivo para editar |
| Runtime, compatibilidad Nix y paquetes | Declarativos y fijados | Actualizables sin reimponer preferencias |

No copiar a ciegas todas las raíces a `user_edits`: un override permanente puede
ocultar cambios del Hub, y un archivo base no marcado como seed puede ser
sobrescrito en el primer materialize. El constructor debe inventariar cada
ruta seleccionada y usar su punto nativo de personalización. No copiar configs
del Hyprland antiguo ni Waybar/nwg-dock dentro de Ryoku.

### Archivos ausentes y existentes

- Seed por **ausencia de cada archivo**, no una marca global que impida
  inicializar un archivo añadido después. Conservar también un enlace personal
  existente, incluso colgante: no seguirlo ni escribir a través de él.
- Si el usuario elimina un archivo que tenga seed personal declarado, una nueva
  preparación puede volver a crearlo. No confundir esto con borrar una regla
  dentro de un store: las preferencias o eliminaciones posteriores en el Hub se
  conservan y no se reinyectan en cada switch.
- Los archivos regulares existentes, incluidos los cambios actuales de Fastfetch,
  tienen precedencia sobre los valores iniciales del repo.
- No guardar snapshots de datos privados o credenciales en Git.

### Migración de instalaciones actuales

Excepción necesaria a la regla anterior: retirar enlaces **demostrablemente
administrados por nuestra generación antigua** que bloquean el arranque de
Ryoku, en particular `.bashrc`, o la edición de preferencias.

Hacer una migración versionada con copia privada previa, conservando contenido
y procedencia del enlace; no escribir a través del Store. Solo sustituir el
bootstrap antiguo conocido, no una `.bashrc` regular personalizada ni un enlace
arbitrario. Para estos últimos, preservar y avisar del import necesario.

Los overrides personales que hoy ya son archivos regulares se conservan.
No aprovechar la migración para restaurar defaults sobre preferencias del Hub.
La segunda activación debe ser idempotente y no recuperar contenido retirado
por el usuario. No borrar archivos ni configuraciones históricas del repo.

## Arranque Bash y Fastfetch

- Publicar los recursos Bash nativos omitidos por el empaquetado Nix, sin usar
  rutas Arch `/usr/share` que no existen en NixOS ni romper la versión fijada.
- El bootstrap inicial respeta Bash no interactivo, carga el entorno NixOS/Home
  Manager necesario y entra en Ryoku una sola vez por shell interactiva.
- El `ryoku-fastfetch` nativo consume el **mismo** `config.jsonc` editable que
  guarda el Hub. No introducir otro `--config`, caché del repo o banner paralelo.
- Conservar funciones y aliases útiles (OMP, Nix, SSH, tmux, búsquedas, etc.) por
  imports separados. No importar de nuevo el arranque anterior entero: duplica
  prompt/Starship, zoxide, fzf, completions y puede ocultar la configuración nativa.
- Mantener blesh y completions compatibles con NixOS sin doble inicialización.
- Validar Save → lectura en terminal nueva; una vista previa no prueba guardado.
  No repetir el banner al hacer source del bootstrap varias veces.

## Alcance real del control desde Ryoku

El Hub controla sus claves soportadas. Los scripts/acciones personales sin
representación nativa siguen siendo archivos importados editables; no prometer
que el Hub pueda editar cualquier código Bash/Lua. Mantener atajos y utilidades
iniciales, pero no una capa de preferencias inmutables que gane siempre al Hub.
No implementar en esta fase un traductor completo de todos los atajos Lua a
acciones nativas multiplataforma: las acciones compatibles deben usar el store;
las demás deben poder quitarse/editarlas en sus overrides de usuario.

Los hooks iniciales tampoco deben congelar rutas a una generación Nix que luego
pueda ser recolectada: usar comandos/rutas estables de la generación activa para
las dependencias de compatibilidad, sin reescribir preferencias para actualizar
un path del Store. El constructor decide el helper mínimo que cumpla esto.

## Trabajo independiente prioritario: DPMS de Envy

El apagado/parpadeo después de lock/sleep sigue abierto en
`nixos/hosts/envy/PENDING.md`. Se encontró un defecto concreto en el proveedor
Hyprland fijado y activo: `act output.power on/off` genera
`hl.dsp.dpms({ state = ... })`, mientras Hyprland 0.56.2 lee **action** y, si falta,
aplica **toggle**. Repetir “on” puede por tanto apagar una pantalla.

La emisión incorrecta también fue reproducida con el binario de esa versión y
un socket/`hyprctl` simulados, sin tocar monitores reales.

Corregir esa traducción en el límite de paquetes existente
`provider-compat.nix`, preservando proveedor, bundle, PATH y materializador
coherentes, del mismo modo que la corrección anterior de Niri. No actualizar
drivers ni desactivar lock/suspensión. Verificar mediante un `hyprctl` simulado
que on/on y off/off emiten acciones explícitas idempotentes, con y sin monitor.
No ejecutar la variante rota, DPMS-off ni suspensiones en la sesión del usuario.

Este defecto explica un mecanismo compatible con el síntoma; no demuestra que
sea la única causa ni resuelve por sí mismo HDMI o el recorte de la LG. La
confirmación física del usuario sigue siendo el criterio de cierre.

Referencias primarias:
- [Hyprland: dispatchers](https://wiki.hypr.land/configuring/core/dispatchers/).
- [Ryoku: incidencia 258](https://github.com/Ryoku-dev/ryoku/issues/258).
- Fuentes fijadas: `wm/hyprland/act.go`, `cli/internal/updater/materialize.go`,
  `apps/bash/ryoku.bash`, `hub/backend/fastfetch.go` y la API Lua del Hyprland fijado.

## Pruebas y entrega

1. RED/GREEN con HOME/XDG aislados y archivos ausentes, editados, enlaces propios,
   enlaces HM conocidos, enlaces colgantes, segunda preparación y seed nuevo.
2. Hash de los cambios actuales de Fastfetch intacto; Save del Hub y llamada
   de terminal usan el mismo archivo. Arranque, imports y banner una sola vez;
   sin inicialización interactiva en Bash no interactivo.
3. Cambiar preferencias, eliminar un import y repetir prepare/materialize:
   cambios conservados; ninguna escritura a través del Store.
4. Mantener atajos iniciales y ventanas auxiliares, startups obligatorios,
   compatibilidad de ambos proveedores y aislamiento de i3/Jarq/modos internos.
5. Pruebas del proveedor DPMS con binario real y controlador simulado; validadores
   reales de ambos compositores y build completo de Envy, sin activación.
6. Revisión independiente antes de commit/push. Documentar exactamente qué
   preferencias son seeds y qué archivos son base/runtime o derivados.

No hay autorización nueva para activar, reiniciar, forzar lock/sleep ni
interrumpir la sesión. Se conserva el flujo anterior: el usuario hace su
`nh os switch` en Envy, salvo que pida explícitamente otro despliegue.
