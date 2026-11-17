# Terminal de osmarg: restauración y evidencia del prompt

## Restauración aplicada en ORGM — 2026-11-17

A petición del propietario se restauraron las copias reales de `kitty`,
`btop` y `starship` con `orgm-dot --profile hyprland pull APP`. Los seeds del
repositorio ya eran correctos; bootstrap conserva las copias existentes y el
rebuild anterior no había eliminado los restos de Ryoku.

Kitty conservaba Space Grotesk a 11 puntos, `current-font.conf` y el include
`user.conf` → `orgm-ryoku.conf` con opacidad 0.85. Ahora usa RobotoMono Nerd
Font Mono a 14 puntos, opacidad 1.0 y la configuración ordinaria del repositorio.
btop seleccionaba `ryoku`; ahora selecciona `Default`. Starship ya contenía
Mythos; se sincronizó también con su seed, sin reemplazar Bash.

Respaldos creados por orgm-dot:

- `20261117T073855.687869017-kitty-pull`
- `20261117T073855.784225585-btop-pull`
- `20261117T073855.876940373-starship-pull`

Después del pull, los tres `orgm-dot diff` quedaron vacíos. El parser instalado
de Kitty confirmó fuente, tamaño y opacidad; se solicitó recarga con SIGUSR1
al proceso Kitty del usuario. Ya no había un proceso btop abierto al aplicar
la restauración. Una PTY con el HOME real y Bash interactivo, tras ejecutar
un comando, verificó lambda, píldoras y colores oro/pizarra de Mythos. Esto
comprueba configuración y render del prompt, no aceptación visual de la
ventana física. No se operaron otros hosts.

## Ajuste posterior del símbolo en ORGM

El propietario aclaró que quiere conservar Starship y quitar únicamente `λ`.
Se añadió el override de equipo
`dotfiles/config/hosts/orgm/shared/.config/starship.toml` con `❯` para éxito
y error. Se aplicó al HOME real con `orgm-dot --profile hyprland pull starship`
(respaldo `20261117T074756.718809279-starship-pull`). Ambos estados renderizan
`❯` sin lambda. El cambio del símbolo no afecta los seeds de otros equipos.

La prueba de PTY se actualizó para el override de ORGM y pasó para GNOME e
Hyprland. En esta validación no se ejecutó Ryoku porque su fuente nativa fijada
no estaba disponible en el store local; la prueba completa mantiene ese requisito.

## Investigación anterior (sin despliegue en esa etapa)

El baseline de T10/S15 ya renderiza Mythos en Bash interactivo para GNOME,
Hyprland y Ryoku. Esta investigación no cambia la configuración ni declara
resuelto el problema observado en la terminal real.

## Evidencia reproducible

Ejecutar desde el checkout:

```sh
python3 tests/osmarg-starship.test.py
```

La prueba usa HOME, checkout, historial, cachés y estado temporales. Importa
**ambas** aplicaciones (`bash` y `starship`) mediante `orgm-dot`, abre Bash en
una PTY y espera el prompt después de cambiar al directorio `prompt-proof`.
Comprueba `λ`, los extremos de las píldoras, el icono/directorio y los colores
RGB oro `#ECA75B` y pizarra `#23252E`, además del TOML seleccionado.

Para Ryoku materializa Bash/rashin/env desde el input disponible en el store
(`/nix/store/rrdyj3sb0iyvw69dm9942d5cxnz4xh9w-source`, revisión fijada
`28c5207586babb136aecf8568ce3ed873fa8f8fd`) y aplica el parche de orden
Starship/zoxide que ya existe en el repositorio. La ausencia de ese input es un
error explícito, no una cobertura omitida. No desactiva los editores ni los
hooks instalados por el sistema. No prueba el materializador completo ni una
sesión gráfica de Kitty.

## Propiedad y cadena de arranque

| Capa | Comportamiento actual |
| --- | --- |
| GNOME/Hyprland | `.bashrc` de osmarg → `/etc/bashrc` → `bash/config.bash` → Starship → zoxide |
| Ryoku | `.bashrc` nativo → `bash/ryoku.bash` → Starship → zoxide → rashin/user → Blesh |
| TOML | La aplicación `starship`, separada de `bash`, posee `.config/starship.toml` |
| Kitty | Ni el seed ordinario ni el nativo inspeccionado fija `shell`; el nativo permite overrides en `user.conf` |
| Copias existentes | Bootstrap conserva cambios personales; un rebuild no repone necesariamente los seeds |

No se añaden excepciones de hostname ni cambios para otros usuarios. Tampoco
se fuerza `STARSHIP_CONFIG`: en esta reproducción está sin definir y Starship
usa el TOML Mythos del HOME privado.

## Qué falta en la terminal afectada

Con autorización del propietario, obtener una captura del prompt **tras un
comando** en la ventana afectada, el shell realmente ejecutado y sus argumentos,
el valor de `STARSHIP_CONFIG`, y una comparación de los archivos de prompt
locales con los seeds. Inspeccionar también los overrides locales de Kitty y
los imports conservados de Ryoku. No copiar secretos ni configuraciones ajenas.
Un `bash -lic '…'` o la existencia de funciones Starship no prueba el render.

No se ha reproducido un conflicto heredado de `STARSHIP_CONFIG`; inventarlo no
explicaría el fallo comunicado. Antes de fijar una política autoritativa hace
falta identificar cuál de estas capas difiere en la ventana real.

## Recuperación local, sólo tras comparar y aprobar

No se desplegó nada en el HOME real. Un rebuild no es una restauración de
copias editables. Si la comparación confirma que **sólo** el TOML difiere:

1. Guardar un backup fechado de `~/.config/starship.toml` y comprobarlo.
2. Revisar `orgm-dot diff starship` en el contexto correcto de osmarg.
3. Sólo con aprobación, usar `orgm-dot pull starship` (también crea respaldo)
   y abrir una ventana nueva para comprobar el prompt después de un comando.

No usar `pull bash` a ciegas: reemplaza más que el prompt y puede perder imports
y funciones personales. Si falta un import, respaldar su archivo y combinar
sólo la línea necesaria después de diagnosticarlo. En Ryoku no reemplazar el
Bash nativo, los edits personales ni el materializador por los seeds ordinarios.
La restauración de un backup y cualquier despliegue siguen siendo decisiones
del propietario; esta tarea no modifica hosts remotos ni el HOME actual.
