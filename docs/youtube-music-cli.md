# YouTube Music en la terminal

Todos los sistemas incluyen `youtube-music-cli` 0.3.6, con los comandos
`ymc` y `youtube-music-cli`, además de `mpv` y `yt-dlp`. Hay un acceso en el
menú que abre la interfaz en una terminal. No inicia automáticamente.

```sh
ymc
ymc --help
ymc login  # opcional, para la biblioteca y las listas personales
```

El paquete utiliza la distribución oficial de npm fijada por hash y Node de
Nix; esto evita depender de un binario Bun compilado para CPUs más recientes.
La compatibilidad en la ThinkPad antigua debe comprobarse en el equipo. La aplicación ejecuta su propio
mpv con el complemento MPRIS, para los controles de medios y la detección de
reproducción del reloj de ORGM. La configuración y las credenciales siguen en
el directorio personal del usuario, fuera de Nix y del repositorio.

Cada equipo recibe la selección al actualizar su configuración NixOS. Se puede
desactivar con `orgm.youtubeMusicCli.enable = false`. Las versiones de
`yt-dlp` y del reproductor siguen los paquetes fijados por el repositorio;
si YouTube cambia sus interfaces, pueden requerir una actualización de Nix.
