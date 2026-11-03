# Pantalla ligera: rueda del mouse

Aplicado en Jarq, generación **62**, sin reboot:
`/nix/store/mjn857km9hgk96isjpjcfxy61c17fq55-nixos-system-jarq-jarq-multimedia`.
Aplicación fijada en `b379de0db10155c73271571e45efa64bac49a60b`.

La rueda sobre la imagen se transmite al punto correspondiente en Jarq. Incluye
scroll vertical y horizontal; Shift+rueda genera horizontal y Ctrl/Cmd conserva
el zoom local. Agrupa eventos cada 250 ms, limita cada eje a seis pasos y actualiza
la imagen durante desplazamientos continuos para renovar el contexto. Al salir
u ocultar la pestaña se descartan las colas pendientes. Fuera de la imagen la
rueda del navegador funciona normalmente.

El endpoint exige autorización, CSRF, captura vigente, coordenadas acotadas,
ejes enteros y contexto de pantalla sin cambios. Usa Sway IPC button4/5/6/7,
con un evento completo por paso. La cuota separada de scroll (240/minuto)
evita consumir las acciones normales del mando.

316 pruebas unitarias y 171 acciones finales de navegador. Prueba nativa en Sway
headless/Chrome de Lenovo: scrollY aumentó al bajar y disminuyó al subir. La prueba
UI verifica la rueda, Shift+rueda y ausencia de envíos fuera de Pantalla; los
límites y mapeos de ejes también tienen pruebas unitarias. No se desplazó una
página del usuario durante la aceptación física.

Compilado en Lenovo desde la base exacta 61 y transferido a Jarq. Se verificaron
el JS servido, endpoint de scroll y rechazo 410 de una captura desconocida sin
inyectar eventos. Servicios activos, ninguna unidad fallida y autorizaciones
conservadas. Guardia temporal de rollback desarmada. Se conserva la generación 61.
No se activó sistema en Lenovo ni se aplicaron los pendientes de Syncthing.

Fuente/evidencias en `~/.local/state/orgm-multimedia/20261103-screen-scroll/`
(ORGM), `/home/jarq/Hobby/nixos-multimedia-screen-scroll/` (Jarq) y
`/tmp/orgm-screen-scroll-20261103/source/` (Lenovo). La fuente anterior se restaura
si quedó Inicio después del switch y esa aplicación continúa abierta.
