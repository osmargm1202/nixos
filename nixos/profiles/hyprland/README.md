# Hyprland con paquetes oficiales de NixOS

Este perfil usa directamente `pkgs.hyprland`, su portal, `pkgs.waybar`,
`pkgs.nwg-dock-hyprland` y `pkgs.mpvpaper` del NixOS fijado en `flake.lock`.
No aplica parches ni versiones de GitHub a esos programas. Sus binarios se
obtienen de la caché oficial cuando están disponibles. Los dotfiles se copian
del checkout con `orgm-dot`; NixOS instala los paquetes y servicios y no vuelve
a imponer la configuración de las aplicaciones. Véase [la guía del helper](../../../dotfiles/README.md).

Las anteriores excepciones fijaban Hyprland 0.56.2, nwg-dock 0.4.11 y
mpvpaper 1.9, y parcheaban Waybar para manejar una señal de Caffeine.
Eso generaba derivaciones distintas de las publicadas por NixOS y obligaba
a compilar localmente. Se retiraron también sus entradas de flake sin cambiar
las revisiones de NixOS, Home Manager o Ryoku.

El perfil no compila ni carga ScrollOverview, HyprGlass o HyprWindowShade.
Conserva las recetas antiguas como referencia, sin instalarlas. Alt+Tab usa
el selector de ventanas de Rofi cuando no hay un plugin de overview cargado;
el desenfoque y las animaciones usan Hyprland. El menú de shaders solo se
muestra si existe un catálogo instalado. Win+Shift+Espacio conserva el cambio
entre ventana flotante y mosaico.

Caffeine mantiene su estado mediante `idle_inhibitor.start-activated` en la
configuración generada de Waybar. No se envían señales RT a un módulo que no
las admite. El dock conserva geometría, lanzador y pines editables.

Envy mantiene Ryoku mientras se prueban los dotfiles, junto con Lenovo y ORGM,
con su conjunto compatible de compositor y plugins. Este perfil queda preparado
como alternativa; no se activa por la migración de dotfiles. La integración de KDE Connect
conserva el pequeño portal local existente, independiente del compositor.
