# Interruptor de pantalla en los controles principales

Aplicado en Jarq, generación 66, sin reboot:
`/nix/store/ngaycq3g2f84gki7sb8qcd82gqmnm6p8-nixos-system-jarq-jarq-multimedia`.
Aplicación `95e1b742fc30716159b08618ba8abd1f953e819e`.

El mando incorpora una tecla junto a Inicio y Cambiar app: «Pantalla fija» /
«Pantalla auto», con aria-pressed y resaltado activo. Se retiró el interruptor
de Administración; se mantiene ahí la explicación del modo. La barra nativa
superior incorpora un botón de pantalla checkable, antes de Encendido. Crece
60 px para alojarlo sin solapar los demás controles. Ambos usan la misma
preferencia persistente y el mismo agente de la generación 65.

El cliente local admite únicamente touch-always-on on/off, convertido a un
booleano explícito. La barra actualiza el indicador con la respuesta y con el
estado periódico; el modo sigue sincronizado entre mando y laptop. El icono
se resalta con fondo y borde al estar activado.

Validación: 339 pruebas unitarias cubiertas y build de paquete completo aprobado;
185 acciones de navegador, tecla accesible en móvil, target >=44 px y ausencia
de overflow. Se inspeccionó captura del mando. En Lenovo, una sesión Sway privada
comprobó toque real en QML -> cliente local -> agente -> estado HTTP, tanto Sí
como No, y captura del botón resaltado. Los reinicios de idle se interceptan
solo en la prueba; las animaciones de emparejamiento no acceden al backlight
del constructor. No se activó ningún sistema en Lenovo.

El smoke completo de navegador nativo se detuvo por no aparecer el archivo
DevToolsActivePort de su fixture Chrome, antes de alcanzar los controles. La
aceptación enfocada en el interruptor reutilizó el fixture aislado sin depender
de ese navegador y pasó: /tmp/orgm-sway-smoke-lzq1ehs3 (Lenovo). No se declara
aprobado el smoke amplio.

En Jarq: activación terminó con status 0; servicios activos, cero unidades
fallidas, HTTPS health 200, JS nuevo servido y tecla dentro de la zona del mando.
Se verificó por IPC que la barra nativa expone el botón dentro de sus límites,
y refleja la misma selección anterior. La selección previa era automática (false)
y se conservó. Autorizaciones intactas; guardia de rollback desarmada.

Fuente exacta archivada en ~/.local/state/orgm-multimedia/20261104-touch-shortcut,
/home/jarq/Hobby/nixos-multimedia-touch-shortcut y /tmp/orgm-touch-shortcut/source
(Lenovo). Captura nativa de prueba en /tmp/orgm-touch-shortcut/touch-toggle-on.png.
