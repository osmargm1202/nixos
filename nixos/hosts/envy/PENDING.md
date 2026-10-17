# Memoria del host: pendientes de Envy

Actualizado: 2026-10-16. Estado: **abierto; proveedor DPMS corregido en la configuración; despliegue y validación visual pendientes**.
Este archivo es seguimiento versionado; no ejecuta acciones al desplegar.

## ENVY-DISPLAY-001 — Parpadeo y apagado tras lock/sleep

### Petición y síntomas

El usuario pide conservar para la siguiente sesión el parpadeo y el apagado de
la pantalla después de bloquear (`lock`) y suspender/reanudar (`sleep`); aclara
que el monitor **no vuelve a encender después de sleep**. Antes
había descrito varios ciclos de apagado/encendido al despertar y problemas al
llevar la imagen al LG. No dar este tema por resuelto porque los servicios de
resume estén activos o una compilación termine correctamente.

Separar en el diagnóstico:

1. **Lock sin suspensión**: identificar cuándo se apaga el panel, si corresponde
   al temporizador DPMS previsto y si vuelve correctamente con actividad/desbloqueo.
2. **Suspend/resume**: comprobar parpadeo repetido, imagen estable, cursor y
   recuperación del panel interno y del monitor externo. No confundir un apagado
   de ahorro esperado con un fallo al recuperar la imagen.

### Contexto preservado (observaciones previas, no estado actual verificado)

- HP ENVY 17m-ce1xxx; Intel UHD para escritorio, NVIDIA MX250 Pascal con offload,
  controlador propietario `legacy_580`, kernel 6.12 LTS y Ryoku/Hyprland.
- Existía una salida fantasma `DP-1` sin EDID a 800×600; el override de Envy la
  desactiva. No retirarlo indiscriminadamente ni desactivar un conector real.
- LG ULTRAGEAR por USB-C apareció como `DP-2`, 2560×1440 ~144 Hz, escala 1;
  el panel interno tenía escala 1,25. El usuario confirmó imagen por USB-C,
  pero contenido cortado en cualquier ventana: **también sigue pendiente**.
- HDMI solo no identificaba la LG en las pruebas anteriores. Revalidar cable,
  entrada y conector antes de atribuirlo a drivers.
- Se corrigió previamente el PATH de servicios Ryoku para disponer del
  `hyprctl` fijado. Eso no demuestra que DPMS/resume funcione visualmente.
- La versión fijada de Ryoku y sus acciones de encendido/DPMS deben inspeccionarse
  al diagnosticar; ninguna causa (driver, cable, escala, lock o DPMS) está confirmada.

### Hallazgo del 2026-10-16: orden de encendido convertida en toggle

Inspección solo lectura en Envy: el proveedor Hyprland activo es el original
`h0g4b6d…-ryoku-wm-hyprland-unstable`, y la política real de hypridle usa
`ryoku wm act output.power on` en `on-resume` y `after_sleep_cmd`.

Se comprobó en las fuentes fijadas que ese proveedor emite
`hl.dsp.dpms({ state = "on" })`, pero la API Lua de Hyprland 0.56.2 lee **action**;
cuando falta, aplica **toggle**. Por tanto, una orden “on” repetida puede apagar
una salida que ya estaba encendida. El defecto fue reproducido con el binario
de esa misma versión, un socket de sesión simulado y un `hyprctl` de prueba:
`on/on/off/off` emitió siempre el campo incorrecto `state`, sin tocar monitores
reales. [Incidencia del proyecto](https://github.com/Ryoku-dev/ryoku/issues/258).

**Corrección implementada, todavía no desplegada en esta investigación.**
`provider-compat.nix` parchea únicamente el proveedor para emitir `action`,
con el mismo binario corregido en PATH, bundle y materializador. La prueba real
con socket/controlador simulado verifica `on/on/off/off` y el monitor opcional;
las repeticiones ya no emiten toggle. No se cambian drivers ni se desactiva
lock/sleep. Sigue pendiente confirmar físicamente si resuelve el
síntoma completo; HDMI y el recorte de la LG se diagnostican por separado.
La sesión observada estaba encendida en eDP-1, con DP-1 fantasma deshabilitado y
sin LG conectada; no hubo una suspensión registrada en ese arranque que permitiese
reproducir aquí el fallo real. No se forzó lock, DPMS-off ni sleep.

### Próxima sesión: evidencia y pruebas no destructivas

- Anotar hora exacta, alimentación CA/batería, tapa, puerto/cable, pantallas
  conectadas, modo extender/duplicar, resolución/frecuencia/escala y si ocurre
  tras lock solamente o tras una suspensión real.
- Guardar el estado antes y después del síntoma, desde una terminal en la sesión
  gráfica y sin cambiar primero el layout:

  ```sh
  date --iso-8601=seconds
  hyprctl -j monitors all
  systemctl --user status hypridle ryoku-shell ryoku-materialize --no-pager
  journalctl --user -b -u hypridle -u ryoku-shell -u ryoku-materialize --since '10 minutes ago' --no-pager
  sudo journalctl -b -k --since '10 minutes ago' --no-pager
  ```

- Revisar la política real de idle/lock/DPMS y las acciones de resume; comparar
  panel interno solo, después LG por USB-C y por HDMI, cada puerto por separado.
- Hacer cambios de una variable a la vez. No actualizar drivers a ciegas,
  desactivar bloqueo, forzar pantallas siempre encendidas ni aplicar layouts
  remotos que puedan dejar al usuario sin imagen.
- Mantener logs completos y snapshots fuera de Git; revisar/redactar datos
  privados antes de publicar cualquier extracto.

**Cierre pendiente:** confirmación física del usuario de lock/unlock y varios
ciclos suspend/resume sin parpadeo persistente ni pérdida de imagen, con los
conectores probados por separado. Registrar aparte el resultado del recorte
LG/escala y de HDMI; no cerrar todo por una sola prueba satisfactoria.

## Gestión rápida de monitores ya declarada (Ryoku/Hyprland)

No se añaden atajos nuevos para esta petición:

- **Super/Win + P**: `ryoku-monitor toggle`, alterna duplicar y extender.
- **Super/Win + Ctrl + G**: abre el Hub; entrar en **Displays/Pantallas** para
  posición, resolución, escala y perfiles de disposición por hardware.
- Abrir directamente esa página: `ryoku-shell hub open displays`.

Comandos manuales existentes:

```sh
ryoku-monitor mirror eDP-1  # Duplicar el panel interno en las demás salidas activas
ryoku-monitor extend      # Extender y reajustar escala/posición automáticamente
ryoku-monitor autoscale   # Recordar disposición coincidente o calcular escala por DPI
ryoku-monitor list        # Consultar pantallas (no aplica cambios)
```

Usar `eDP-1` solo si ese es el nombre que muestra `list`. `mirror` sin argumento
usa la pantalla enfocada como origen. Solo se duplican/extienden las salidas
habilitadas: no se corrige así un HDMI que todavía no se detecta.

**Atención:** toggle/mirror/extend/autoscale aplican cambios en vivo y guardan la
configuración generada; no son vistas previas ni una corrección del fallo de
lock/sleep. Los overrides personales en `monitors_user.lua` tienen precedencia.
Antes de cambiar de modo, recoger el estado del fallo si se quiere diagnosticar.
La vinculación de teclas puede haber sido modificada posteriormente en el Hub;
aquí se documenta la configuración declarada, no una comprobación física en Envy.

Fuente fijada: `ryoku/hyprland/modules/binds.lua` y
`ryoku/hyprland/scripts/ryoku-monitor` de la entrada `ryoku` del flake.
Referencia del proyecto: [comandos Ryoku](https://github.com/Ryoku-dev/ryoku-docs/blob/main/docs/commands.mdx).
