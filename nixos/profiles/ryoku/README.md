# Ryoku para Osmarg

Perfiles independientes: `orgm-ryoku` y `lenovo-ryoku`. Se usa el módulo oficial
de [Ryoku on NixOS](https://github.com/aethctl/Ryoku-on-NixOS), fijado en
`28c5207586babb136aecf8568ce3ed873fa8f8fd`. Su nixpkgs se conserva separado:
Hyprland, plugins, portales y Quickshell deben usar el mismo conjunto compatible.

Desde la raíz del repo:

```bash
nh os build path:. -H lenovo-ryoku
nh os switch path:. -H lenovo-ryoku -s windows-vfio
```

`-s windows-vfio` conserva ese modo de Lenovo. Para elegir normal usa `-S`.
En ORGM usa `-H orgm-ryoku -S`. Tras aplicar, cierra la sesión y entra de nuevo
en Hyprland: cambiar el paquete del compositor necesita una sesión nueva.
`path:.` incluye los archivos nuevos antes de registrarlos en Git.

Ryoku controla barra, dock, fondos, temas, Kitty, Neovim, monitores, bloqueo,
idle y notificaciones. Las aplicaciones y herramientas de Osmarg conservan su
selección habitual. Se mantienen sus menús de SSH, Pi, archivos, Obsidian,
Firefox, Windows/RDP y AI, sin arrancar Waybar, nwg-dock ni el gestor visual anterior.

Los atajos personales se leen directamente de la configuración de Osmarg para
Hyprland. Las acciones de escritorio usan los controles de Ryoku. Las colisiones
se trasladan a `Super+Ctrl+Alt+Shift+tecla`; si esa combinación ya está ocupada se
usa una tecla de función libre. `Super+/` muestra la lista efectiva; también:

```bash
orgm-ryoku-shortcuts --list
```

`never-ask` se configura por usuario en Hyprland y Ryoku. Crea una colección nueva
`orgm-never-ask`, sin contraseña, y conserva los llaveros cifrados anteriores.
Los secretos antiguos permanecen en esas colecciones; no se migran ni se borran.
La política PAM se define en Nix, sin modificar `/etc` desde el escritorio.

Ryoku materializa sus configuraciones editables al activar Home Manager y al
iniciar su sesión. Los overrides de integración se copian como archivos normales,
porque el materializador omite los enlaces del overlay. Al volver a otro perfil,
los archivos editables que ese perfil necesita reemplazar se guardan bajo
`~/.local/state/orgm-ryoku/return-*`. Los ajustes iniciales del teclado se siembran
una vez; las modificaciones posteriores desde Ryoku se conservan.

Lenovo mantiene normal, batería, gaming, Windows/VFIO y server. Gaming y server
deshabilitan Ryoku completo, incluidos Niri y los servicios de la shell. ORGM
conserva su especialización server. El controlador y los dispositivos VFIO
siguen perteneciendo a los módulos de hardware existentes.

## Verificación

```bash
bash tests/ryoku-shortcuts.bats.sh
python3 tests/test_ryoku_keyring.py
bash tests/ryoku-transition.bats.sh
bash tests/ryoku-profile.bats.sh
```

La prueba de atajos usa los módulos de la revisión fijada de Ryoku: conserva
128 atajos personales y reubica 74 colisiones, incluidos nombres equivalentes
de teclas como `Next` y `Page_Down`. Se comprobaron las transiciones con archivos
editables y enlaces, y la conservación de los llaveros existentes.

Se evaluaron el módulo oficial y todos los modos de arranque de Lenovo y ORGM
con `tests/ryoku-profile.bats.sh`. Esa comprobación valida las opciones e
integración declarativa; no sustituye una construcción completa. Antes de
activar, ejecuta `nh os build path:. -H lenovo-ryoku` en tu terminal y revisa
su resultado.
