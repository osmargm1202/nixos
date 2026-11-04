# Barra contextual del teléfono para buscar y escribir en webapps

Aplicado en Jarq, generación 68, sin reboot:
`/nix/store/dd91a8bj25w4dx0ni1apld4c7466y32r-nixos-system-jarq-jarq-multimedia`.
Aplicación: `262b380a1792c663f293c877906712831d9c2cb9`.

La barra de entrada está dentro del mando, debajo del nombre de la app, y se
reutiliza en Pantalla ligera. Sustituye la pantalla de texto genérico y el panel
separado de búsqueda; videos locales conserva una sección propia. La lupa fuerza
búsqueda de contenido en la app seleccionada. El botón Teclado enfoca la barra.
Si hay un campo Chromium enfocado, muestra «Campo seleccionado» y escribe ahí
con Enter; en ausencia de campo usa el alias de búsqueda configurado del servicio.
En Inicio queda deshabilitada.

Las capturas fullscreen incluyen hasta 32 rectángulos editables, sin valores.
Al tocar uno se enfoca el input del teléfono dentro del propio gesto, antes de
esperar HTTP. Después se confirma el elemento realmente enfocado y se habilita
el envío. El borrador queda ligado a app y campo, no se redirige silenciosamente
al cambiar el contexto. Tokens de cinco minutos y comprobación de ventana,
foco y nodo DOM; CSRF, autenticación, límites y payloads estrictos. No se leen
valores de campos, tampoco contraseñas. El texto se envía al pulsar Buscar/Enter,
no carácter a carácter. El servicio no agrega listeners ni puertos públicos.

Se corrigió el éxito falso del buscador DOM sin input. Chrome usa CDP insertText
y Enter. YouTube/VacuumTube y Spotify emplean sus accesos al buscador y el mapa
latam del teclado nativo persistente, en vez de Ctrl+V o keymaps efímeros. Los
acentos y signos españoles están cubiertos; caracteres fuera del mapa nativo
se rechazan antes de empezar a escribir. Las webapps admiten Unicode por CDP.

Validación: 344 pruebas unitarias, 182 acciones de navegador. La prueba retiene
la respuesta del clic y comprueba que la barra ya tiene foco, permite preparar
el texto y mantiene Enter deshabilitado hasta confirmar el destino. CDP real:
Unicode literal, Enter, búsqueda SPA Netflix en fixture, campos cambiados o
eliminados rechazados, contenteditable, borrado y ausencia de valores secretos.
Privacidad y tamaño IPC incluyen 100 campos simulados, acotados a 32 en respuesta.

Sway/Chrome privados en Lenovo: captura y clic nativos, scroll, teclado latam
persistente con acentos/ñ/signos, detección DOM y envío del teléfono con Enter.
El fixture inicia un teclado semilla antes del navegador, como la barra QML,
y añade después el teclado idéntico del agente. Mantiene ambos vivos; no cambia
ni retira keymaps durante la escritura. Evidencia: /tmp/orgm-screen-native-wl91imgb.
No se utilizaron pantallas ni gestores de sesión reales del constructor.

Build en Lenovo desde la fuente exacta conservada de generación 67. Se transfirió
el NAR fijado desde ORGM y se compiló offline; no se activó Lenovo. En Jarq:
activación exitosa, endpoint de detección autenticado, HTML/JS nuevo, rechazo
422 de token malformado sin escribir, HTTPS health 200, servicios activos y cero
unidades fallidas. Autorizaciones y selección Auto/Fija conservadas. Rollback
desarmado. No se inyectaron consultas en las apps reales durante la aceptación.

Aceptación móvil pendiente: teclado del SO y consulta real en YouTube. En Safari
u otros móviles que bloqueen foco automático, se toca la barra. Marcos externos
no se recorren; la detección está limitada a inputs/editables y shadow DOM abierto
del documento enfocado. Cada alias sigue sujeto a la UI/sesión de su servicio.

Fuente archivada en ~/.local/state/orgm-multimedia/20261104-phone-keyboard/source,
/home/jarq/Hobby/nixos-multimedia-phone-keyboard y /tmp/orgm-phone-keyboard/source
(Lenovo). Capturas UI en /tmp/orgm-browser-2mfdp5qv (ORGM).
