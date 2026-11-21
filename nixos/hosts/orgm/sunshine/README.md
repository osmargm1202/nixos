# Sunshine y Moonlight en orgm

`apps.json` contiene el catálogo que Sunshine publica en Moonlight. Para cambiarlo,
edita este archivo y guarda las nuevas portadas PNG en `covers/`. El catálogo usa
`@home@` para la carpeta del usuario y `@config@` para su directorio XDG de
configuración. Los ajustes de Sunshine y de i3 viven en `../i3-session.nix`.
El acceso a `https://sun.or-gm.com` se configura en `../web-panels.nix`.

Al conectar o reanudar en Moonlight, i3 enfoca la ventana de la entrada que se está
transmitiendo. Los accesos de Steam y Lichii se reconocen por sus comandos de
lanzamiento. Otras apps se identifican por su nombre o por la clase X11 de su
ejecutable. En las entradas de escritorio, i3 recupera la ventana que tenía el
foco al desconectarse si sigue abierta.

Home Manager instala el catálogo y conserva una copia de la última versión aplicada
en `~/.local/state/sunshine/versioned-catalog/`. Si hiciste cambios desde el panel
de Sunshine y aparece un aviso de edición local, compara esa copia con
`~/.config/sunshine/apps.json`. Incorpora en Git los cambios que quieras conservar.
Si también cambiaste el catálogo en Git, integra ambos cambios en el archivo local
antes de volver a activar Home Manager. Tras activar un cambio de catálogo,
reinicia `sunshine.service` cuando puedas interrumpir la transmisión.

El lanzador de Lichii vive en `~/Apps/lichii-linux-x86_64-pgo/tools/launch-lichii.sh`
y las entradas de emulación apuntan a juegos en `~/Games/S2`. Restaura estos
archivos desde su propia copia antes de usar esas entradas. Los juegos de Steam
requieren Steam y sus instalaciones locales.

Los certificados, las claves y `sunshine_state.json` se guardan por separado.
Si restauras en una instalación sin ese estado, vuelve a emparejar los clientes
Moonlight. El archivo de preferencias del cliente Moonlight también contiene sus
claves y se mantiene fuera de Git.
