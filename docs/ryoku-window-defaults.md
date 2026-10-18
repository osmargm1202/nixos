# Ventanas iniciales de Osmarg en Ryoku

En los hosts Ryoku de Osmarg (`lenovo`, `orgm`), las ventanas nuevas de
navegadores y webapps usan una columna del **100 % del ancho disponible**, sin
ocultar la barra. Es ancho de columna, no fullscreen: conserva márgenes y
espacio reservado del monitor. En Hyprland esto corresponde al layout scrolling;
no se cambia el layout que hayas elegido en el Hub.

El cliente de Windows `windows-rdp` abre en **fullscreen real**. No afecta al
selector `windows-rdp-prompt`, a terminales ni a ventanas por su título. No cambia
el transporte RDP ni activa `/f` en SDL FreeRDP (se conserva la protección frente
al fallo de superficie 64×64). No instala ni inicia una VM Windows.

## Fuente y propiedad

- Fuente inicial única por usuario/perfil:
  `dotfiles/config/users/osmarg/profiles/ryoku/.config/orgm-ryoku/window-defaults.json`.
- `native-session.py` añade las reglas una sola vez a
  `~/.config/ryoku/desktop.json`, bajo el mismo lock del Hub. Conserva reglas y
  datos anteriores, evita duplicados exactos y hace un backup privado en
  `~/.local/state/orgm-ryoku/desktop.before-window-defaults-v1.json`.
- Después del primer seed, las modificaciones y eliminaciones en el Hub se
  conservan: no se vuelven a imponer los valores iniciales en cada despliegue.
- Niri traduce `columnwidth` directamente. `provider-compat.nix` corrige en el
  paquete fijado su serialización de anchos enteros: Niri requiere `1.0`, no
  `1`. La misma versión corregida se usa desde el Hub/PATH, el materializador,
  su servicio y Home Manager, sin modificar las reglas del usuario.
- El proveedor Hyprland fijado en el lock actual omite esa acción; se genera `native-window-widths.lua` desde las
  reglas efectivas del mismo store y lo carga el módulo personal. Es una
  adaptación local, no una segunda lista de aplicaciones. Los cambios de ancho
  hechos en el Hub se reflejan en esta adaptación durante la siguiente
  preparación/activación; no se promete actualización inmediata en Hyprland.
- Un ancho vacío/no numérico usa `0.5`, como el proveedor Niri. Los anchos
  fuera del rango proporcional `(0, 1]` se omiten con aviso en la adaptación
  Hyprland, sin modificar el store ni bloquear la preparación.
- Fullscreen permanece en los proveedores nativos de ambos compositores.
  Se preservan las reglas especiales de ventanas auxiliares y Bitwarden.
- i3 y el usuario Jarq no reciben estos valores.

La API de Hyprland distingue el ancho proporcional de scrolling del estado
fullscreen; véase su [documentación del layout scrolling](https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/).
La configuración generada se valida además con los binarios Hyprland y Niri
fijados por el flake, no solamente contra documentación de versiones recientes.

## Aplicar en un host Ryoku

Envy usa ahora Sway; esta configuración solo se aplica a Lenovo y ORGM.
No se realiza activación remota como parte de este cambio. Tras actualizar el
checkout en `~/Hobby/nixos`, ejecuta allí:

```sh
nh os switch . -H lenovo
```

Reabre las aplicaciones para comprobar las reglas iniciales. No se redimensionan
las ventanas ya abiertas ni se modifica la elección manual de ancho posterior.
La comprobación visual en el hardware queda pendiente de esa activación.

## Verificación sin activación

- 19 casos de migración: seed único, backup, preservación de preferencias y
  datos, deduplicación, valores vacíos/no válidos sin bloquear la preparación.
- Renderizado de los proveedores fijados y validación real de Niri y Hyprland;
  coincidencia de navegadores y las 28 webapps del catálogo, exclusión de
  selectores/terminales/Bitwarden, y callbacks auxiliares conservados.
- Prueba del cableado de paquetes, bundle, PATH del servicio, Home Manager y
  wrapper transaccional del materializador.
- Build histórico de Envy con su anterior perfil Ryoku aprobado. No sustituye la comprobación visual al abrir
  aplicaciones después del switch del usuario.
