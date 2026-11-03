# ORGM: captura de Discord y activación de pendientes

Sistema aplicado: generación 286,
`/nix/store/6ry9qi0yrpawj6vxpv08m9kxfznp3f90-nixos-system-orgm-hyprland`.
Incluye Syncthing: unidad de usuario activa/habilitada, Linger=yes. No se aplicó
ningún sistema en Lenovo, Envy ni Jarq durante esta tarea.

## Diagnóstico y alcance

Dispositivo conectado: Mpow HC, USB 0d8c:0014, serial
C-Media_Electronics_Inc._Mpow_HC_20170817. Perfil guardado/activo:
output:iec958-stereo+input:mono-fallback. Micrófono físico al 153% en PipeWire,
control ALSA Mic en paso 35 (+23 dB) y Auto Gain Control activado.
La captura inicial mostró entrada WEBRTC desde el micrófono físico, no desde
un monitor de reproducción. No se grabó audio ni se reprodujeron señales de
prueba. Estos datos justifican corregir perfil/ganancia pero no demuestran por
sí solos la causa acústica o eléctrica de la fuga reportada.

## Configuración aplicada

Regla WirePlumber por identidad USB exacta, no por índice de tarjeta. ACP propio
con perfil analógico dúplex y sin IEC958: la selección digital anterior ya no es
restaurable. La ruta de micrófono limita el control físico al paso 12 (0 dB) y
apaga el AGC, que este modelo expone como interruptor de reproducción. No se
cambian los perfiles de otros USB, Bluetooth ni el ajuste previo de Corsair.

PipeWire Pulse aplica block-source-volume a Discord nativo/Flatpak. Esta regla
impide a sus clientes alterar el volumen global del micrófono; no bloquea grabación,
sonido de pantalla compartida ni el procesado/ganancia internos de la aplicación.
Se conservaron las preferencias generales previas de audio integrado. En la
sesión activa se eligieron las nuevas salida analógica y entrada Mpow para retirar
la referencia de salida IEC958 desaparecida.

## Activación y validación

Home Manager fallaba desde antes por tres enlaces antiguos de tmux. Se respaldaron
sin borrar datos en ~/.local/state/nixos-activation-backups/20261103-audio, con
manifest; Home Manager instaló los enlaces declarativos y terminó correctamente.
La activación vía pkexec terminó, sin reiniciar el equipo; posteriormente se
recargó pipewire-pulse para que la regla se aplicara a los clientes reconectados.

Build completo de ORGM aprobado; prueba previa orgm-audio-policy.bats.sh aprobada.
Estado real tras activar: perfil analógico, micrófono físico 0 dB, AGC off,
PipeWire/Pulse/WirePlumber/Syncthing activos y ninguna unidad fallida de sistema
ni usuario. Se confirmó que el cliente de prueba tiene application.process.binary
Discord; el servidor devuelve Access denied al intentar cambiar el volumen de
la fuente, que permanece igual. tests/orgm-audio-live.test.py repite esa comprobación
sin grabar, restaura el volumen inicial incluso si falla.

Pendiente de aceptación humana: comprobar en llamada si desapareció la fuga al
reproducir audio en audífonos sin compartir pantalla; si persiste, distinguir
filtración física del adaptador/cable de procesado interno de Discord. No se
promete que un límite de ganancia elimine un cruce eléctrico real.

Referencias:
- https://docs.pipewire.org/devel/page_module_protocol_pulse.html
- https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html
- https://raw.githubusercontent.com/PipeWire/pipewire/1.6.6/spa/plugins/alsa/acp/alsa-mixer.c
