# Botón de señal externa

Aplicado en Jarq, generación 64, sin reiniciar el equipo:
`/nix/store/k01vyvg5w9dvx06xf6ir52hzrxfp8cig-nixos-system-jarq-jarq-multimedia`.
Aplicación: `45f6c6fb652113201c134dc9dfaa9d38aeb871e3`.

Encendido del dashboard/mando incorpora «Apagar pantalla externa» / «Activar
pantalla externa». El agente usa Sway power off/on sobre HDMI-A-1, preserva
ventanas y deja intacta la pantalla interna. El watcher respeta el apagado
solicitado en lugar de reencender HDMI cada dos segundos. Marcador privado en
XDG_RUNTIME_DIR compartido por agente y watcher; persiste reinicios de servicios,
no reinicios del equipo. Una desconexión física y reconexión devuelve la señal.

La espera/apagado sin señal depende del dispositivo. No se envía CEC. Encender
un monitor que mantiene HDMI conectado no garantiza una notificación: en ese
caso se reactiva con el botón. El audio HDMI también puede verse afectado por
el apagado de la salida.

326 pruebas unitarias y 183 acciones de navegador. Se cubren respeto del apagado
tras reiniciar watcher, recuperación por reconexión, tipos estrictos, rechazo sin
salida, reversión de preferencia si falla Sway, CSRF y cambio de etiqueta en el
mando. Compilado en Lenovo desde la fuente exacta de la generación 63; ninguna
activación en Lenovo ni inclusión de pendientes Syncthing.

Aceptación en Jarq: HDMI reconocido, estado conectado/encendido, JS nuevo servido,
endpoint autenticado de encendido idempotente y rechazo 422 del tipo incorrecto.
Se dejó HDMI encendido: no se probó físicamente su apagado durante la reproducción
del usuario. Servicios activos, ninguna unidad fallida, HTTPS /api/health 200,
autorizaciones conservadas y aplicación previa restaurada. Rollback desarmado.

Fuente conservada en ~/.local/state/orgm-multimedia/20261103-external-power/source,
/home/jarq/Hobby/nixos-multimedia-external-power y /tmp/orgm-external-power/source
(Lenovo).
