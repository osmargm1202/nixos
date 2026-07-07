# Battery alerts + power profiles automáticos

**Fecha:** 2026-07-07
**Script:** `config/profiles/hyprland/.local/bin/hypr-battery-alerts` (copia idéntica en `hyprlandqs-caelestia`)
**Test:** `tests/hypr-battery-alerts-test.sh`

## Objetivo

Extender el daemon existente de alertas de batería para que además gestione
power profiles vía `powerprofilesctl`, con umbrales nuevos de notificación.

## Comportamiento

### Descargando (`status = Discharging`)

Cada umbral dispara una sola vez por ciclo de descarga (marcas en state file):

| Umbral | Acción |
|--------|--------|
| ≤30%   | Notificación normal |
| ≤20%   | Notificación normal "Batería baja" |
| ≤10%   | Notificación crítica + `powerprofilesctl set power-saver` |
| ≤5%    | Notificación crítica "BATERÍA CRÍTICA" |

- Solo notifica el umbral más severo cruzado (elif en cascada); el cambio a
  power-saver es independiente (marca `act-saver`), así un salto directo de
  100% a 4% notifica la crítica Y activa el ahorro.
- Al empezar a descargar se limpian las marcas `charge-*`.

### Con AC (`Charging`, `Full`, `Not charging`, etc.)

| Umbral | Acción |
|--------|--------|
| ≥50%   | `powerprofilesctl set balanced` (una vez por ciclo de carga) |
| ≥90%   | `powerprofilesctl set performance` (una vez por ciclo de carga) |

- Al conectar AC se limpian las marcas `notif-*` y `act-*`.
- Decisión: los perfiles solo suben con AC conectada; descargando nunca se
  sube el perfil. Si se desconecta a >90% el perfil se mantiene hasta cruzar
  el 10%.

## Mecánica

- Todo es edge-triggered: el daemon solo actúa al cruzar un umbral, nunca
  re-aplica el perfil en cada tick. Un cambio manual (waybar-power-profile
  pick) se respeta hasta el próximo cruce.
- State file: `$XDG_STATE_HOME/hypr-battery-alerts/state`, un token por
  línea (`notif-30`, `notif-20`, `notif-10`, `notif-5`, `act-saver`,
  `charge-50`, `charge-90`).
- `powerprofilesctl` con guard `command -v` y `|| true`: hosts sin
  power-profiles-daemon solo pierden esa parte, las notificaciones siguen.
- Overrides para pruebas: `HYPR_BATTERY_ALERT_CAPACITY`,
  `HYPR_BATTERY_ALERT_STATUS`, `HYPR_BATTERY_ALERT_PPCTL`,
  `HYPR_BATTERY_ALERT_INTERVAL`.
- Sin cambios en autostart ni en nix: mismo nombre de script, ya arranca
  como daemon desde autostart.lua en ambos perfiles hyprland.
