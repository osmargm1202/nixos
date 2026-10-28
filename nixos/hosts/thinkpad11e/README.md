# thinkpad11e

Lenovo ThinkPad 11e (20DAS17400), Celeron N2940 de cuatro núcleos sin AVX,
4 GB de RAM, Intel Bay Trail/i915, Wi-Fi Intel 7260 y SSD LiteOn de 128 GB.
El ahorro de energía Wi-Fi queda desactivado: durante la instalación provocó
avisos de balizas perdidas y bloqueos del tráfico SSH.
Usuario: `hm`. Escritorio: variante ligera de i3, sin compositor ni Quickshell.

Instalación autorizada sobre todo el SSD, en BIOS/Legacy:

| Partición | Uso |
| --- | --- |
| sda1 | 2 MiB, bios_grub |
| sda2 | 4 GiB, swap de respaldo |
| sda3 | resto del SSD, ext4 para / y /home |

El hardware generado contiene los UUID de esta instalación. GRUB se instala
en `/dev/sda`; no se utiliza systemd-boot. Zram LZ4 tiene prioridad sobre la
swap del SSD. TRIM es periódico; `/` utiliza noatime. La tapa suspende salvo
cuando está acoplada a una pantalla externa. No se configura hibernación.

Las preferencias de hm viven en `nixos/users/hm.nix` y
`dotfiles/config/users/hm/`. Incluyen Steam y la selección clásica de emuladores:
RetroArch con núcleos para NES, SNES, GB/GBC, GBA, Mega Drive, N64, PS1,
arcade, Atari y PC Engine; además Dolphin, PPSSPP y PCSX2 nativos. DuckStation
utiliza el Flatpak definido en el catálogo porque Nixpkgs retiró su paquete.
La instalación de PS2/GameCube/PSP no garantiza velocidad completa en este CPU.
No se incluyen ROM, juegos comerciales ni BIOS.

ArtCraft Launcher 0.8.1 y CADCraft 0.13.0 son bundles oficiales con SHA-256.
El launcher permite acceder a la biblioteca sin instalar toda la suite.
El inicio de sesión no arranca Firefox, Steam ni clientes de IA automáticamente.
hm también selecciona Chromium con Widevine, las webapps generales, Kitty como
terminal adicional, Spotify, Warehouse y Flatseal. Los perfiles Chromium permanecen
en el SSD; no se sincronizan a RAM. Win+Enter utiliza Xterm y la barra i3status
usa letra de 9.5 puntos. Xterm permite escritura OSC 52 para copiar desde SSH/tmux.

CADCraft 0.13.0 mostraba una ventana negra con OpenGL acelerado en Bay Trail.
La excepción de este host usa OpenGL por software (llvmpipe), dos hilos y vsync;
se comprobó que dibuja la interfaz. El resto de aplicaciones conserva aceleración
gráfica. Esta compatibilidad puede reducir el rendimiento de dibujos complejos.

La pantalla integrada anuncia 1366×768. Los menús Rofi del perfil ligero usan
como máximo 480 px de ancho y ocho filas en esta pantalla, con desplazamiento
para el resto de opciones. La prueba gráfica sobre el equipo midió 480×291 px.

Instalación arrancada y configuración activada el 2026-10-28. Se corrigieron
los dos fallos de Autorandr previos al inicio de sesión y el ciclo de ordenación
entre la instalación de Flatpak y las integraciones ArtCraft. Autorandr solo
despacha eventos cuando existe la sesión i3; ArtCraft termina su integración
desde graphical.target. La comprobación posterior mostró cero unidades fallidas
del sistema y del usuario. La variante ligera no intenta iniciar el teclado
en pantalla deshabilitado.

Las contraseñas se provisionan fuera del repositorio. SSH acepta al usuario hm;
root por SSH permanece desactivado. `authorized_keys` contiene únicamente la
clave pública autorizada durante la instalación.

Consultar `nixos/profiles/i3/README.md` para replicar la variante en otro equipo.
