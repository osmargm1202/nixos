# Hyprland con paquetes oficiales de NixOS

Este perfil usa directamente `pkgs.hyprland`, su portal, `pkgs.waybar`,
`pkgs.nwg-dock-hyprland` y `pkgs.mpvpaper` del NixOS fijado en `flake.lock`.
El compositor no se modifica; Waybar y el dock llevan los parches de
compatibilidad con su API Lua (véase el informe de dock/anchos). Sus binarios
se obtienen de la caché cuando están disponibles. Los dotfiles se copian
del checkout con `orgm-dot`; NixOS instala los paquetes y servicios y no vuelve
a imponer la configuración de las aplicaciones. Véase [la guía del helper](../../../dotfiles/README.md).

Las anteriores excepciones fijaban Hyprland 0.56.2, nwg-dock 0.4.11 y
mpvpaper 1.9, y parcheaban Waybar para manejar una señal de Caffeine.
Eso generaba derivaciones distintas de las publicadas por NixOS y obligaba
a compilar localmente. Se retiraron también sus entradas de flake sin cambiar
las revisiones de NixOS, Home Manager o Ryoku.

ScrollOverview de [yayuuu](https://github.com/yayuuu/hyprland-scroll-overview)
restaura la vista de workspaces tipo Niri en Alt+Tab y Alt+Shift+Tab. Se compila
contra **el mismo Hyprland 0.55.4**, usando la revisión `cfc23b194ba9378d1606c7aa73060f6ffbe38445`
fijada por su tabla de compatibilidad; no se actualiza el compositor ni se omite
la comprobación ABI. NixOS instala `/etc/scrolloverview.so`. El módulo Lua
`overview` lo registra mediante `hl.plugin.load` al evaluar cada configuración,
no mediante un proceso asíncrono al iniciar. Se conserva scrolling y la vista
vertical a escala 0.5. Flechas y Enter permiten elegir otra ventana; también
se puede hacer clic en la vista.

Si el plugin no está disponible o su dispatcher falla, ambos atajos conservan
el selector Quickshell anterior. **Sway sigue usando su selector actual**:
este plugin depende de las API internas de Hyprland y no funciona en Sway.
HyprGlass e HyprWindowShade siguen sin instalarse. El desenfoque y las
animaciones usan Hyprland; Win+Shift+Espacio alterna flotante/mosaico.

Para aplicar sin cambiar la generación NixOS, se puede compilar la receta
contra el mismo `pkgs.hyprland` y dejar su salida como GC-root en
`~/.local/state/orgm-hyprland-tools/scrolloverview`. El módulo consulta
`$XDG_STATE_HOME` (por defecto `~/.local/state`) y usa ese `.so` solo si no
existe `/etc/scrolloverview.so`. `orgm-dot --repo <checkout> pull hyprland`
copia los módulos; `hyprctl reload` registra/carga el plugin. Tras una
activación normal, `/etc/scrolloverview.so` tiene prioridad. No usar `hyprpm`
en paralelo para cargar una segunda copia.

Caffeine mantiene su estado mediante `idle_inhibitor.start-activated` en la
configuración generada de Waybar. No se envían señales RT a un módulo que no
las admite. El dock conserva geometría, lanzador y pines editables.

Envy mantiene Ryoku mientras se prueban los dotfiles, junto con Lenovo y ORGM,
con su conjunto compatible de compositor y plugins. Este perfil queda preparado
como alternativa; no se activa por la migración de dotfiles. La integración de KDE Connect
conserva el pequeño portal local existente, independiente del compositor.
