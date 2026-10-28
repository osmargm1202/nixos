# Jarq: envío de videos exactos de YouTube

El mando incorpora **YouTube en Jarq**, con campo de enlace y botón Enviar.
La ruta rápida solicitada funciona con la autorización del navegador:

```
https://home.or-gm.com/youtube/link/?key=https://www.youtube.com/shorts/pM9H2Pvr_-s
```

El GET sirve la interfaz y no modifica la sala. Una navegación explícita de nivel
superior (`Sec-Fetch-User`, modo navigate, destino document) permite que el cliente
haga el POST autenticado con cookie/CSRF. Las vistas previas, iframes y peticiones
GET sin esa intención no reproducen nada. Sin sesión aparece la vinculación usual;
al aceptarla se puede completar el envío. `key` es el enlace, no una credencial.

Se usa una validación compartida por atajo, API y agente: HTTPS, dominios exactos
de YouTube/youtu.be, un identificador de once caracteres y rutas watch, shorts,
live o embed. Se rechazan texto adicional, dominios similares, credenciales,
puertos distintos de 443, canales, listas sin video e IDs duplicados. Se preservan
inicios t/start válidos; se eliminan listas y seguimiento. No se hace una consulta
externa para adivinar disponibilidad o superar restricciones de una cuenta.
La validación ocurre antes de abrir/enfocar y no ejecuta texto como shell.

VacuumTube recibe el enlace por su CLI nativa, con URL como argumento posicional
y fullscreen. Su protocolo de instancia única reutiliza la ventana abierta.
Esto está documentado en el [repositorio oficial de VacuumTube](https://github.com/shy1132/VacuumTube#command-line-options).
Se comprobó contra VacuumTube 2.0.1 instalado en Jarq.

## Atajo en ORGM y Envy

**Win+Alt+Y** lee PRIMARY mediante wl-paste (o xclip en X11), valida la selección
completa y abre la ruta rápida codificada en el navegador predeterminado. No
reutiliza contenido anterior del portapapeles. La lectura tiene tamaño y tiempo
limitados, admite entregas fragmentadas y espera EOF para evitar aceptar un enlace
truncado antes de texto inválido. No hay repetición al mantener la tecla pulsada.

El helper usa la autorización de ese navegador; no lee/copía sus cookies, no
extrae el secreto de la sala y no se autoriza por IP. Si ese navegador aún no está
vinculado, el usuario solicita permiso y lo acepta en Jarq. El dominio actual
sigue requiriendo Tailscale.

- Declaración Nix: `nixos/apps/youtube-send.nix`, importada por ambos hosts.
- Hyprland: configuración común y copia personal de osmarg; Envy: Sway.
- Instalación en vivo en ambos usuarios sin reconstruir sus sistemas completos:
  `~/.local/bin/orgm-send-youtube` y perfil Nix privado de paquetes en
  `~/.local/state/orgm-home/youtube-send/profile`.
- La envoltura prefiere el binario global cuando una reconstrucción futura lo
  instale; mientras tanto usa ese perfil con raíz de GC. No contiene credenciales.
- Paquete final: `/nix/store/czc2wkc41mdvib24fcvjyan99x1cfpxm-orgm-send-youtube`.
- Copias previas de los archivos de configuración en el mismo directorio de estado.
- Hyprland recargado y binding real Y/modmask72/repeatfalse comprobado. Envy
  recargado y regla real Sway con `--no-repeat` comprobada. Ambos helpers dieron
  exactamente la URL esperada con --dry-run.

## Despliegue y validación

- Aplicación pública: `0974d5007b363a0cad65abf28ff141329cf5b41c`.
- Jarq: generación **54**, sistema activo y predeterminado
  `/nix/store/2q1rc5l6aihyl4p4vp7jsij1vhgf3ngr-nixos-system-jarq-jarq-multimedia`.
- Generación 53 anterior conservada. Despliegue con guardia temporal de rollback,
  aceptada y timer detenido tras validación. No se reinició el equipo.
- API, Nginx, DIAL y cinco servicios de sesión activos; ninguna unidad fallida.
- **237 pruebas unitarias**: enlaces y esquemas inválidos, identidad/tiempo,
  autorización/CSRF, GET sin efectos, selección fragmentada, arranque y reutilización.
- Navegador real: **140 acciones**, formulario móvil, rechazo de enlace ajeno,
  envío válido y enlace rápido en navegador vinculado; sin errores de página.
  Capturas `/tmp/orgm-browser-ytvv9w71`; Bomba simulada también aprobada.
- NixOS compilado, contenido del paquete y evaluación del helper en ambos hosts
  correctos. VM de arranque aprobada en
  `/nix/store/s0iqii1sq5a2r1qfvkna6vnqm4snif4c-vm-test-run-orgm-multimedia-boot`.
- Sesión real aislada Sway/Chrome/Quickshell aprobada con el paquete final:
  `/tmp/orgm-sway-smoke-_z35rodn`. Un primer pase agotó la espera del cursor Home;
  la repetición instrumentada pasó sin errores HTTP ni cambios en el producto.
  No se atribuye una causa no demostrada a esa condición intermitente del harness.
- Jarq físico: enlace inválido mantuvo la fuente; un mando sin cookie recibió 401;
  un GET de vista previa no cambió la sala; POST válido recibió el video exacto,
  reutilizó una sola ventana fullscreen y retuvo el timestamp.
- Prueba adicional desde YouTube cerrado creó la ventana. La captura de una
  ventana oculta durante la carga fue gris; al comprobarla enfocada se observó
  el Short vertical de NBA proporcionado. No se usa la ausencia de URL MPRIS como
  prueba de fallo: ese reproductor no expuso allí el identificador del video.
- Se volvió a Spotify al terminar. Evidencias privadas:
  `/tmp/orgm-youtube-acceptance.log`, `orgm-youtube-private-check.log`,
  `orgm-youtube-focused-check.log` y captura `orgm-youtube-window-focused.png`.

Las políticas de YouTube, disponibilidad del video o una cuenta sin seleccionar
siguen perteneciendo a la aplicación. La confirmación Enviado indica entrega de
la orden; no promete disponibilidad universal. Solo se publican los cambios de
esta tarea, preservando los trabajos paralelos del checkout principal.
