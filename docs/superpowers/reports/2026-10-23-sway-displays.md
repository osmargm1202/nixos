# Sway / nwg-displays — aplicar y guardar pantallas

## Causa comprobada en Jarq
nwg-displays0.4.3 abría correctamente en su sesión. El usuario confirmó que fallaba al aplicar/guardar. La app del menú usa `Exec=nwg-displays`, que escribe `~/.config/sway/outputs` y `workspaces`; Sway solo incluía `outputs.conf`/`workspaces.conf`. Existía el archivo generado `outputs` con dos pantallas, mientras el `outputs.conf` incluido seguía siendo un comentario. El centro de control además forzaba `-o outputs.conf`, dividiendo las rutas según el punto de entrada.

El error al ejecutar --help por SSH sin SWAYSOCK no se confundió con el fallo del usuario: con el entorno gráfico importado, --help funciona. No se cambió el gestor de pantallas ni se instaló otro programa.

## Corrección
- Sway sigue cargando primero los defaults/manuales por host `outputs.conf` y `workspaces.conf`; después incluye los archivos nativos generados `outputs` y `workspaces`.
- Centro de control Sway usa `nwg-displays -n10`, sin ruta alternativa. Hyprland conserva su comando independiente sin cambios.
- Configuración generada por equipo sigue siendo editable/local: no se añadieron posiciones, seriales ni resoluciones particulares a los dotfiles.
- Se aplicaron solamente esos cambios exactos en HOME y fuente Sway activa de Jarq, preservando sus overrides nativos y el resto del backend. No se reemplazó el árbol ni se hizo switch/reboot.

Este uso coincide con la [documentación oficial de nwg-displays](https://github.com/nwg-piotr/nwg-displays#sway).

## Seguridad del despliegue
Antes de recargar, el script comprobó que todos los outputs guardados coincidían con los actuales en resolución/refresh, posición, escala, transformación y estado activo, para no activar silenciosamente un layout viejo. Se validó el config completo con su Sway nativo; reload exitoso y geometría comparada sin cambios. No se enviaron pulsaciones/clics ni se cambiaron resoluciones del escritorio del usuario. Backup exacto:
`/home/jarq/.local/state/orgm-displays/backups/20261023T061327Z/` (index y metadata previa).

## Pruebas
- RED: Sway privado ignoraba escala/posición guardadas en `outputs`; el test del comando CC también fallaba por -o outputs.conf.
- GREEN:7tests del centro de control;10de sway-desktop; prueba de bundle instalado.
- Sesión Sway real aislada con dos salidas virtuales, tanto localmente como con Sway nativo de Jarq: archivos nativos guardados aplican escala/posición y mueven workspace7 al segundo output, sobreponiéndose a defaults manuales sin modificarlos. El caso inicial sin archivos generados sigue utilizando defaults.
- El fixture espera la aplicación asíncrona del reload antes de consultar el estado; no asume que la respuesta IPC significa que ya terminó el commit de outputs.
- `git diff --check` limpio. Sin commit/push.

## Uso
Abrir **Pantallas / nwg-displays**, ajustar, aplicar y confirmar dentro de la cuenta atrás. También sirve desde Centro de control → Pantallas. Sway sigue siendo el compositor que controla físicamente los outputs; nwg-displays es su interfaz gráfica. No hace falta cerrar sesión.
