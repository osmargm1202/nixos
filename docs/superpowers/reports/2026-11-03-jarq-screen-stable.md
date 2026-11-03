# Pantalla del mando sin destellos al renovar capturas

Aplicado en Jarq, generación 63, sin reiniciar el equipo:
`/nix/store/pnsb4rgzh0q9z96amffkaq6wjgm3a3g8-nixos-system-jarq-jarq-multimedia`.
Aplicación: `a2313b5d90f59e2d6e9471efb9f34dffe35ccb22`.

La imagen visible recibía el nuevo src antes de terminar su descarga y
decodificación. Ahora se carga en un elemento separado y se sustituye la imagen
visible solamente cuando está lista. Si falla o el usuario sale de Pantalla,
no se presenta esa captura. Se conserva el auto cada dos segundos y su pausa
al salir u ocultar la pestaña.

316 pruebas unitarias y 178 acciones finales de navegador. La prueba de regresión
retiene la respuesta JPEG y verifica que la imagen anterior permanece conectada,
decodificada y con el mismo src; al liberar la respuesta se comprueba el reemplazo.
Los frames de la prueba tienen identificadores distintos como en producción.

Compilado en Lenovo desde la fuente exacta de la generación 62. No se activó
Lenovo ni se incluyeron los cambios pendientes de Syncthing. Tras aplicar se
verificaron el JS servido, sesión autenticada, HTTPS /api/health 200, servicios
activos y ausencia de unidades fallidas. Token y dispositivos autorizados sin
cambios; se restauró la aplicación que estaba abierta. Rollback desarmado.

Fuentes: ~/.local/state/orgm-multimedia/20261103-screen-stable/source (ORGM),
/home/jarq/Hobby/nixos-multimedia-screen-stable (Jarq),
/tmp/orgm-screen-stable/source (Lenovo).
