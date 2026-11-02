# Jarq: mando físico para smartphone

Aplicado el 2026-11-01, generación **57**, sin reboot:
`/nix/store/4j7i76649xdx975nvhqn2856aayqksfl-nixos-system-jarq-jarq-multimedia`.
Aplicación fijada en `98566dd6e524c52d0f1bf8a9649e9f34fe6da799`.

Hasta 720 px, el mando tiene carcasa de grafito, pantalla de estado hundida,
cruceta circular, OK plateado, teclas con relieve y efecto de pulsación. Los seis
servicios usan sus logos a color sobre teclas claras. Los controles principales
quedan dentro de la carcasa; Tab/Shift+Tab e ingreso de enlaces permanecen debajo.
En escritorio se mantienen botones planos con textos y los seis accesos en fila.
La dirección se documenta en docs/design-handset.md de la aplicación.

La generación se compiló en Lenovo usando la base exacta instalada y cambiando
solo la aplicación. No se activó sistema en Lenovo. Jarq recibió la clausura y
se aplicó con retorno automático temporal, desarmado tras las comprobaciones.

Validación: 261 pruebas unitarias y 139 acciones de navegador. Se inspeccionaron
las capturas móvil y escritorio; las comprobaciones cubren 390×844, 320×640 y
1440×1000, ausencia de desbordamiento horizontal y objetivos de al menos 44 px.
Los controles principales caben por encima de la navegación fija a 390×844.
Las capturas usan un agente simulado, no una película del usuario.

En Jarq se verificaron HTML, CSS responsive y SVG a color servidos por la nueva
aplicación; HTTPS 200, servicios activos, ninguna unidad fallida y hashes de
autorizaciones conservados. YouTube quedó en pantalla, junto a Inicio y Spotify
abiertos. El backend de reproducción, búsqueda y cambio de app no cambió.

Fuente y evidencias: `~/.local/state/orgm-multimedia/20261101-handset/` en ORGM;
fuente archivada en `/home/jarq/Hobby/nixos-multimedia-handset/` y compilación en
`/tmp/orgm-handset-20261101/source/` de Lenovo. Generación 56 conservada.
