# Starship de osmarg: reproducción antes de cambiar el prompt

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
