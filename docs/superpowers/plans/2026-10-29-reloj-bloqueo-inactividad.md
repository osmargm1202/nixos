# Plan: reloj y bloqueo por inactividad en ORGM

**Estado (29 de octubre):** implementado y activado en ORGM. El reloj y el bloqueo se probaron en una sesión Wayland aislada; el bloqueo manual sigue usando Qylock. El servicio detectó la reproducción activa en la sesión real. La prueba del plazo completo en la sesión real queda pendiente de uso normal.

## Objetivo

Mostrar un reloj de tarjetas abatibles similar a Fliqlo cuando ORGM esté inactivo. Durante la primera etapa, cualquier movimiento o tecla vuelve al escritorio sin contraseña. A los diez minutos de inactividad total, bloquear la sesión y requerir autenticación. El reloj debe poder seguir visible en el bloqueo.

El primer umbral propuesto es **3 minutos**; los diez minutos se cuentan desde la última interacción, no desde que aparece el reloj. El diseño y el primer umbral se podrán ajustar antes de implementar.

## Situación actual

- ORGM usa Hyprland y `hypridle`, con `orgm-qylock lock` a los 600 segundos y suspensión a los 900. El bloqueo manual y el previo a suspensión usan Qylock.
- Quickshell y `playerctl` están disponibles. Los reproductores que utilizan inhibidores de inactividad de Wayland suelen impedir los temporizadores mientras muestran video; la música requiere comprobar también MPRIS.
- Qylock es el mecanismo de bloqueo y autenticación existente. El reloj previo es una pantalla visual que no protege la sesión; el bloqueo real comienza a los diez minutos o inmediatamente cuando se solicita manualmente.

## Comportamiento

1. A los 3 minutos sin interacción y sin reproducción activa, mostrar sobre cada monitor una pantalla negra con la hora grande, blanca, en dos tarjetas animadas de horas y minutos. Debe ajustarse al tamaño de cada pantalla y admitir 12/24 horas.
2. Antes de los 10 minutos, cualquier interacción cierra esa pantalla y devuelve el foco al escritorio. No solicita contraseña y reinicia el contador de inactividad.
3. A los 10 minutos de inactividad total, iniciar Qylock y exigir contraseña. Pasar del reloj visual al bloqueo solo cuando el bloqueo Wayland esté confirmado, evitando un destello del escritorio. El reloj seguirá visible si se puede incorporar al tema de Qylock de forma fiable.
4. Al bloquear manualmente, suspender o cerrar la sesión, usar el bloqueo con contraseña inmediatamente, sin periodo de gracia. Mantener el comportamiento de seguridad existente si el reloj falla o se cierra.
5. No mostrar el reloj ni activar el bloqueo automático mientras se reproduzca audio o video. Si empieza la reproducción mientras se muestra el reloj, retirarlo. Respetar los inhibidores de Wayland y consultar **todos** los reproductores MPRIS disponibles para detectar `Playing`. Al terminar o pausar la última reproducción, comenzar un nuevo periodo de inactividad sin depender de un clic; no detener ni cambiar la reproducción. El bloqueo manual y el previo a suspensión siguen funcionando.
6. Conservar inicialmente la suspensión automática de los 15 minutos, sujeta a las mismas condiciones multimedia. Si se desea mantener el reloj encendido más tiempo, cambiar ese plazo de forma explícita durante la implementación.

## Implementación propuesta

1. Crear una superficie Quickshell en capa superior por monitor, con reloj local y animación breve al cambiar cada minuto. No utilizar videos ni consultar servicios externos. Capturar actividad de teclado, ratón y táctil para cerrar limpiamente la superficie; manejar desconexión y conexión de monitores.
2. Añadir un coordinador pequeño por sesión para las etapas `activo`, `reloj` y `bloqueado`. Usar los eventos de inactividad y reanudación de Hyprland/hypridle y observar MPRIS, con una única instancia y temporizadores idempotentes. Evitar carreras entre actividad, fin de reproducción, bloqueo y suspensión; al iniciar o detener el servicio, limpiar únicamente sus propios recursos.
3. Integrar el aspecto del reloj en Qylock sin desactivar PAM ni sustituir su flujo de autenticación. Comprobar que Qylock haya adquirido el bloqueo de sesión antes de retirar el reloj previo. Si la integración visual del tema no resulta viable sin debilitar el bloqueo, conservar el tema actual y documentar esa limitación.
4. Actualizar `dotfiles/config/profiles/hyprland/.config/hypr/hypridle.conf` y el servicio de sesión correspondiente; mantener una única fuente para los tiempos y la detección multimedia. No ignorar globalmente los inhibidores de Wayland.
5. Añadir configuración editable para umbral inicial, formato horario y suspensión, con valores predeterminados documentados. Mantener los datos y preferencias personales existentes.

## Comprobación antes de aplicar

- Probar en una sesión aislada con tiempos cortos: entrada al reloj, salida por cada tipo de interacción, transición a bloqueo y desbloqueo autenticado.
- Verificar que los 10 minutos parten de la última actividad, que una interacción antes del límite reinicia el contador y que el bloqueo manual/pre-suspensión es inmediato.
- Simular varios reproductores MPRIS: uno en `Playing`, pausas, cierre de reproductor, reproducción que empieza durante el reloj y reproducción que termina sin más interacción. Probar también un inhibidor Wayland de video.
- Comprobar varios monitores, cambios de resolución, monitores desconectados, reinicio del coordinador y fallo del reloj. Un fallo visual no debe impedir que Qylock bloquee ni dejar el escritorio accesible después del umbral.
- Confirmar que el protector no consume audio ni provoca llamadas a Internet y que la animación usa pocos recursos.
- Después de revisar el resultado, aplicar a ORGM y probar con la persona usuaria; no bloquear ni suspender una sesión real durante las pruebas aisladas.

Los tiempos se ajustan en `~/.config/hypr/hypridle.conf`. Para usar formato de
12 horas, añadir `Environment=ORGM_CLOCK_12H=1` al servicio de usuario
`orgm-hyprland-media-idle.service` y reiniciarlo. La detección de audio usa
MPRIS: las aplicaciones que no lo ofrecen deben proporcionar un inhibidor de
inactividad para evitar el reloj y el bloqueo automático.
