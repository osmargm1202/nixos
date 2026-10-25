# Bomba de agua

La bomba es el dispositivo Tuya **Bomba de Agua**, categoría `znjdq`, producto
`au6dqazvkxqnpaak`. El dispositivo **Casa** es otro interruptor: nunca se usa
`switch.casa_switch` para estos comandos.

```bash
bomba up       # Enciende y cancela cualquier cuenta atrás anterior.
bomba down     # Apaga y cancela la cuenta atrás.
bomba time 10  # Enciende durante diez minutos.
bomba status   # Consulta el estado real.
```

`time` acepta minutos enteros de 1 a 1440, según el máximo de 86400 segundos
de este modelo. La cuenta atrás se programa en el propio interruptor Tuya;
no se implementa con `sleep` en una terminal. Una nueva duración sustituye la
anterior. Un fallo al confirmar la cuenta atrás solicita apagar la bomba y
devuelve error.

## Conexión

OrgM y Jarq tienen instancias independientes de Home Assistant. OrgM conserva
su token en `~/.config/bomba/ha-token`; el de Jarq se guarda en
`/var/lib/bomba/ha-token`, propietario `bomba`, modo 0600. Ambos archivos son
privados y quedan fuera del store. Los IDs previstos en Nix son `switch.bomba`
y `number.bomba_countdown`, configurables en `orgm.bomba`.

Jarq instala la aplicación **Home Assistant** en el catálogo multimedia. Escucha
en loopback y se publica mediante el Nginx existente únicamente en Tailscale:
`http://100.122.22.48:8123`. La cuenta inicial y la vinculación de Smart Life se
completan desde esa página. El soporte de la categoría Tuya `znjdq` ya está
incluido. El acceso local del navegador se limita a 127.0.0.1:8123.

Envy usa SSH por Tailscale con una clave dedicada. Su autorización en OrgM
ejecuta únicamente `bomba gateway`, sin shell ni forwarding. La clave del servidor
SSH se fija a partir de la clave pública local de OrgM. Las claves privadas se
generan en cada cliente y no se incorporan al repositorio ni al store.

Jarq multimedia usa un servicio `bomba` dedicado y un socket
`/run/bomba/control.sock` accesible al grupo `bomba-clients`. Primero comprueba
la disponibilidad de su propio Home Assistant. Si falta el token, la instancia
no responde o todavía no existen las entidades, recurre al gateway de OrgM.
El botón indica «Control local de Jarq» o «Respaldo OrgM activo».

Después de comenzar una escritura, un fallo no repite la orden en otro
controlador: devuelve el error y solicita apagar si no pudo confirmar el
temporizador. Así una respuesta perdida no duplica comandos físicos. Se
conserva el bloqueo general de salida a redes privadas para el UID de `media`;
el navegador no recibe el token ni las claves SSH.

## Multimedia

El botón **Bomba** abre un selector de **5, 10, 15, 20, 30 y 40 minutos**, muestra
el estado consultado y ofrece **Apagar ahora**. Abrirlo no enciende el equipo.
Las acciones conservan la vinculación del mando, validación de origen y CSRF.
Los controles quedan deshabilitados si no se puede confirmar el estado.

La ampliación de la app está en `orgm-multimedia` y también se aplica como
`nixos/profiles/multimedia/bomba.patch` sobre la revisión fijada por este flake,
para que un rebuild no dependa de un checkout mutable ni de publicar cambios.

## Verificación

```bash
python3 tests/bomba.test.py
# En el checkout de orgm-multimedia:
uv run --extra test pytest -q
uv run --with playwright python tests/browser_pump.py /ruta/apps.json
```

Las pruebas de programación y apagado usan un interruptor simulado. La prueba
contra el equipo real debe distinguir confirmación de la API y observación del
apagado físico al terminar el tiempo.
