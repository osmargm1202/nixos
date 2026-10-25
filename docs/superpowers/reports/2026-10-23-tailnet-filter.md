# Selector: solo Linux conectados

El usuario pidió retirar equipos incompatibles/desconectados y conservar los Linux visibles de su red o compartidos por otros usuarios.

## Aplicado en OrgM y Jarq
`merge_targets` exige **OS == linux y Online is True** antes de crear cualquier fila. Excluye Self como antes. No filtra por propietario, UserID ni sufijo DNS: un Linux compartido que Tailscale haga visible sigue apareciendo.

Se retiró el fallback a peers configurados: un equipo ausente, desconectado, con otro OS o sin metadata válida no reaparece por tener perfil VNC. Si Tailscale no está autorizado/disponible, la lista está vacía y se informa claramente. Esto reemplaza explícitamente la política de fallback del primer despliegue. El CLI directo `connect PEER` y la autenticación de los transportes no cambian.

No se escanearon servicios ni se intentaron logins para determinar permisos. Estar online no demuestra que un servidor SSH esté habilitado o autorice el usuario; los métodos de conexión mantienen ese requisito. “Otras redes” significa dispositivos compartidos visibles en Tailscale, no acceso arbitrario a tailnets ajenas.

## Evidencia
- RED:3regresiones detectaron OS incorrecto, fallback sin metadata y peers ausentes reapareciendo.
- GREEN:11tests del selector +11de transporte, revisión independiente22/22. Casos Windows/macOS/Android/iOS/OS vacío, Linux desconectado/estado desconocido, perfil preparado que no debe saltarse filtros y Linux compartido con propietario/sufijo DNS diferente.
- Prueba real Rofi en Sway privado: dispositivo/protocolo/usuario y dispatch de escritorio/argv SSH pasan, con efectos simulados y sin input real del usuario.
- Fuente instalada real de ambos equipos:7Linux online cada uno al verificar, conjunto idéntico al subset esperado de Tailscale; Self y resto excluidos. Sin conexiones a otros peers.
- `git diff --check` limpio. No servicios reiniciados ni cambios de red, SSH, claves o VNC.

Backups por equipo: `~/.local/state/orgm-remote-desktop/backups/linux-online-20261023T064050Z/` (fuente e instalado). Solo se sustituyó `connections.py` en HOME y fuente activa, preservando el resto del trabajo. Sin commit/push.

Cerrar y volver a abrir **Conectar a equipo** actualiza la lista.
