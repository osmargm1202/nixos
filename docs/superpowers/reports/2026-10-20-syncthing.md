# Recuperación de Syncthing — 2026-10-20

## Goal

Restablecer la sincronización observada como inactiva en orgm/Hyprland.

## Instructions

- Aplicar la reparación local, sin pedir al usuario que ejecute el pull.
- Mantener configuración, identidad, carpetas y ausencia de bandeja.
- No activar toda la generación NixOS/Home Manager ni hacer commit/push.

## Discoveries

- No había proceso ni listener GUI; la unidad empaquetada aparecía `disabled`
  e `inactive`. No era un fallo de conexión entre dispositivos.
- El journal del 19 de octubre muestra que la activación de Home Manager
  retiró los enlaces antiguos de Syncthing durante `orgmRetiredTrayBackups`
  y luego abortó en `checkLinkTargets` por una colisión de `.local/bin/orgmai`.
  Por ello nunca se instalaron los enlaces del servicio de reemplazo.
- La unidad correcta ya existía en la generación Home Manager construida
  `/nix/store/8511lh93pwvp1f2qbsb1a5h79djjvv7c-home-manager-generation`.
  La definición declarativa actual también es correcta y tiene
  `WantedBy=default.target`, independiente del compositor o de la bandeja.
- Al revisar, `orgmai` ya apuntaba al mismo binario que esa generación;
  no se cambia ni se vuelve a ejecutar la activación global en esta tarea.

## Accomplished

- Prueba previa real falla: `Syncthing is-enabled: disabled`.
- Se restauran **únicamente** los dos enlaces ausentes desde el directorio
  `home-files` de esa generación: la unidad y su pertenencia a `default.target`.
  Se verifica ausencia de destino antes de crearlos; no se sobrescriben archivos.
- Se ejecutan `systemctl --user daemon-reload` y `start syncthing.service`.
  No se usa un launcher de bandeja ni una segunda instancia.
- Prueba posterior pasa: `enabled`, `active/running`, `NRestarts=0`, API local
  autenticada `/rest/system/ping` devuelve `pong`.
- El certificado y la clave privada originales conservan sus hashes.
  No se editan API keys, dispositivos, carpetas, modos o preferencias.
- API: un peer conectado de uno conocido; dos carpetas no pausadas,
  una idle sin pendientes y otra syncing. Los archivos pendientes de la
  segunda bajan de 1369 a 1204 entre muestras; cero errores de pull/carpeta
  y cero errores recientes del sistema. No se afirma sincronización terminada.
- `tests/orgm-hyprland-transition.bats.sh` pasa: el repositorio ya declara
  el servicio de fondo. `git diff --check` pasa. No se modifica código Nix
  ni se repite la suite completa: reparación operativa, no cambio de fuente.

## Next Steps

- Dejar finalizar la descarga pendiente; el servicio arrancará con la cuenta
  de usuario mediante `default.target`.
- El estado histórico fallido de `home-manager-osmarg.service` no se reinicia
  aquí. Verificar la activación completa en una próxima operación controlada;
  esta recuperación no demuestra que toda Home Manager esté aplicada.
- No se hace commit/push. Los cambios previos de ScrollOverview se conservan.

## Relevant Files

- `~/.config/systemd/user/syncthing.service` — enlace recuperado a la unidad
  declarativa de la generación existente.
- `~/.config/systemd/user/default.target.wants/syncthing.service` — arranque
  automático recuperado, apuntando al archivo correspondiente de `home-files`.
- `~/.local/state/syncthing/` — configuración, identidad y base existentes;
  no se reinicializan ni se borran datos.
- `nixos/syncthing/user-service.nix` — definición correcta, sin cambios.
- `nixos/common-dotfiles.nix` — integración y cleanup del que se obtuvo el
  diagnóstico, sin cambios.
- `/tmp/orgm-syncthing-healthcheck.py` — verificación operativa antes/después,
  nunca imprime el API key.
