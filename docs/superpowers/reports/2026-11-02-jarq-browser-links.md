# Enlaces web generales hacia Navegador

Aplicado en Jarq, generación **59**, sin reboot:
`/nix/store/79s57px8djrljc9gpk0d8w61czw275ws-nixos-system-jarq-jarq-multimedia`.
Aplicación fijada en `9de9eaef42f493a733f2d98adf5ce7fad93f8083`.

Win+Alt+Y, el formulario del mando y los enlaces rápidos envían a Navegador los
HTTP(S) que no correspondan a los servicios reconocidos. Se conservan ruta,
query y fragmento. El Navegador existente reutiliza su página enfocada por CDP;
no se fuerza reproducción automática en sitios genéricos. Los enlaces mal
formados de servicios conocidos siguen rechazándose.

La validación local rechaza esquemas, credenciales, puertos y direcciones privadas
no permitidos; el receptor comprueba DNS antes de despachar y activar la fuente.
La política de salida de Chrome sigue bloqueando destinos privados, incluidos
los que aparezcan tras redirecciones. No se modificó el firewall.

304 pruebas unitarias; navegación CDP aislada con la URL suministrada y todos sus
parámetros conservados, una sola página; 144 acciones del mando en navegador.
El sistema se compiló en Lenovo a partir de la generación 58 y se transfirió a
Jarq. Guardia temporal de rollback desarmada después de verificar el resultado.
Servicios activos, ninguna unidad fallida, HTTPS 200 y autorizaciones conservadas.

En ORGM se actualizó el perfil del emisor a la versión 4 y el helper existente,
conservando su cookie. Se ejecutó el envío real de la URL de redirectus.net
proporcionada por el usuario, incluidas sus dos comas finales: respuesta correcta
y Jarq en la aplicación browser. Esto verifica envío y activación, no el contenido
ni el funcionamiento del sitio externo o de sus redirecciones.

Fuente/evidencias en `~/.local/state/orgm-multimedia/20261102-browser-links/` de
ORGM, `/home/jarq/Hobby/nixos-multimedia-browser-links/` de Jarq y
`/tmp/orgm-browser-links-20261102/source/` de Lenovo. Se conserva la generación 58.
No se activó sistema en Lenovo ni se aplicaron los pendientes de Syncthing.
