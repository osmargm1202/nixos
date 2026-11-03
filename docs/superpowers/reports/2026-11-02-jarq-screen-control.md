# Pantalla ligera: captura a petición y clic

Aplicado en Jarq, generación **60**, sin reboot:
`/nix/store/4nad72m9qs1zma93nlqnzrdrmp4aix1g-nixos-system-jarq-jarq-multimedia`.
Aplicación fijada en `5435f3201c0610f212b72ba3dcd85f5e3208ef6e`.

El mando añade Pantalla bajo los servicios. Imagen fija por defecto, Actualizar,
clic izquierdo sobre la imagen y Volver al mando. Auto cada 2 s es opcional y se
pausa con la pestaña oculta; salir corta las actualizaciones y libera la imagen.
No hay stream de vídeo/audio, servicio adicional ni puerto VNC abierto. Usa el
mando autorizado y CSRF existente. El backend sigue siendo FastAPI + agente Sway.

JPEG de calidad 55, escala máxima 0,5/lado aproximado de 1024 px, una captura
vigente y caducidad de 30 s. Antes de un clic se comprueban identidad, tiempo,
ventana, salida, escala y rotación; las coordenadas están acotadas a la imagen.
La liberación del botón está en finally. El JPEG privado no pasa por static ni
por el catálogo de previews. La salida de la vista no activa Inicio en Jarq.

## Validación

314 pruebas unitarias en Nix y 151 acciones de navegador, incluyendo apertura,
clic, cierre, autenticación, límites, caducidad y ausencia de nuevas capturas al
salir. Se inspeccionó la vista móvil con una imagen sintética.

En una sesión Sway/Chrome aislada de Lenovo se localizó un objetivo en el JPEG y
se activó por la ruta nativa de Sway, verificando el evento en la página. Captura
76 ms, clic 35 ms y JPEG 9696 bytes. El fixture registra un puntero virtual porque
el compositor headless carece de ratón físico; el clic probado se envía por Sway
IPC. La posición del objetivo se toma de la captura, no de coordenadas CSS de
Chrome, que excluyen sus decoraciones y no son coordenadas de pantalla.

En Jarq físico: POST de captura autorizado y GET del JPEG correctos; 506 ms por
captura vía HTTP local y 55885 bytes. Se comprobó Cache-Control no-store, rechazo
de clic con captura desconocida (410) y eliminación del JPEG al cerrar. No se
hizo clic en el contenido del usuario: el clic real se validó en la sesión aislada.
HTTPS 200; servicios activos, ninguna unidad fallida y autorizaciones conservadas.

La generación se compiló en una copia temporal de Lenovo usando la base exacta
59 y cambiando solo la aplicación; no se activó sistema en Lenovo. Transferida
con nix copy y aplicada con guardia temporal de rollback, desarmada tras validar.
Se conserva la generación 59 y los pendientes de Syncthing del checkout.

Fuente/evidencias en `~/.local/state/orgm-multimedia/20261102-screen/` (ORGM),
`/home/jarq/Hobby/nixos-multimedia-screen/` (Jarq),
`/tmp/orgm-screen-20261102/source/` y `/tmp/orgm-screen-native-ycbot_cq/` (Lenovo).
Uso y detalles en docs/screen-control.md de la aplicación.
