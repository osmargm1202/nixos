#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_DIR/config/profiles/hyprland/.local/bin/hypr-battery-alerts"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/state"
CALLS="$TMP/calls"
: >"$CALLS"

make_stub() {
	local name="$1" body="$2"
	printf '#!/usr/bin/env bash\nset -euo pipefail\n%s\n' "$body" >"$TMP/bin/$name"
	chmod +x "$TMP/bin/$name"
}

make_stub notify-send 'echo "notify-send $*" >>"$CALLS"; exit 0'
make_stub powerprofilesctl 'echo "powerprofilesctl $*" >>"$CALLS"; exit 0'

fail() {
	echo "FAIL: $*" >&2
	echo "--- calls ---" >&2
	cat "$CALLS" >&2
	exit 1
}

run_once() {
	local capacity="$1" status="$2"
	env PATH="$TMP/bin:$PATH" \
		CALLS="$CALLS" \
		XDG_STATE_HOME="$TMP/state" \
		HYPR_BATTERY_ALERT_CAPACITY="$capacity" \
		HYPR_BATTERY_ALERT_STATUS="$status" \
		bash "$SCRIPT" once
}

count_calls() {
	grep -c -- "$1" "$CALLS" || true
}

reset_all() {
	: >"$CALLS"
	rm -rf "$TMP/state"
	mkdir -p "$TMP/state"
}

# 1. 28% descargando: notifica una sola vez, sin cambio de perfil.
reset_all
run_once 28 Discharging
run_once 27 Discharging
[ "$(count_calls 'Batería al 30%')" = "1" ] || fail "esperaba 1 notificación de 30%"
[ "$(count_calls powerprofilesctl)" = "0" ] || fail "no debía tocar perfil a 28%"

# 2. Descarga progresiva: 18% notifica baja, 8% activa ahorro + notifica, 4% crítica.
run_once 18 Discharging
[ "$(count_calls 'Batería baja')" = "1" ] || fail "esperaba notificación de 20%"
run_once 8 Discharging
[ "$(count_calls 'powerprofilesctl set power-saver')" = "1" ] || fail "esperaba power-saver a 8%"
[ "$(count_calls 'Batería al 10%')" = "1" ] || fail "esperaba notificación de 10%"
run_once 8 Discharging
[ "$(count_calls 'powerprofilesctl set power-saver')" = "1" ] || fail "power-saver debía aplicarse una sola vez"
run_once 4 Discharging
[ "$(count_calls 'BATERÍA CRÍTICA')" = "1" ] || fail "esperaba notificación crítica a 4%"

# 3. Salto directo a 4% (estado limpio): crítica + ahorro en la misma pasada.
reset_all
run_once 4 Discharging
[ "$(count_calls 'powerprofilesctl set power-saver')" = "1" ] || fail "esperaba power-saver en salto directo a 4%"
[ "$(count_calls 'BATERÍA CRÍTICA')" = "1" ] || fail "esperaba crítica en salto directo a 4%"
[ "$(count_calls 'Batería al 30%')" = "0" ] || fail "no debía notificar 30% a 4%"

# 4. Cargando: 55% pone balanced una vez, 91% pone performance una vez.
reset_all
run_once 55 Charging
run_once 60 Charging
[ "$(count_calls 'powerprofilesctl set balanced')" = "1" ] || fail "esperaba balanced una vez a ≥50%"
run_once 91 Charging
run_once 95 Charging
[ "$(count_calls 'powerprofilesctl set performance')" = "1" ] || fail "esperaba performance una vez a ≥90%"

# 5. Full cuenta como AC: enchufado a 100% pone performance.
reset_all
run_once 100 Full
[ "$(count_calls 'powerprofilesctl set performance')" = "1" ] || fail "esperaba performance con status Full"

# 6. Ciclo completo: cargar re-arma notificaciones, descargar re-arma perfiles de carga.
reset_all
run_once 8 Discharging
run_once 55 Charging
run_once 91 Charging
run_once 80 Discharging
run_once 8 Discharging
[ "$(count_calls 'powerprofilesctl set power-saver')" = "2" ] || fail "esperaba power-saver de nuevo tras recarga"
[ "$(count_calls 'Batería al 10%')" = "2" ] || fail "esperaba notificación de 10% de nuevo tras recarga"
run_once 55 Charging
[ "$(count_calls 'powerprofilesctl set balanced')" = "2" ] || fail "esperaba balanced de nuevo en segundo ciclo de carga"

# 7. Cargando a 30% no notifica ni toca perfil.
reset_all
run_once 30 Charging
[ "$(count_calls notify-send)" = "0" ] || fail "no debía notificar cargando a 30%"
[ "$(count_calls powerprofilesctl)" = "0" ] || fail "no debía tocar perfil cargando a 30%"

echo "OK: hypr-battery-alerts"
