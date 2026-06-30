#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/shared/.local/bin/hypr-usb-menu"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/state" "$TMP/config"
CALLS="$TMP/calls.log"
export HYPR_USB_TEST_TMP="$TMP"
: >"$CALLS"

fail() { echo "FAIL: $*" >&2; [ -f "$CALLS" ] && cat "$CALLS" >&2; exit 1; }

[ -f "$SCRIPT" ] || fail "hypr-usb-menu should exist"
grep -Fq '#!/usr/bin/env bash' "$SCRIPT" || fail "hypr-usb-menu should be a bash script"
for subcommand in status open nickname; do
  grep -Eq "(^|[[:space:]])${subcommand}($|[[:space:]|)])" "$SCRIPT" || fail "hypr-usb-menu should support $subcommand"
done
grep -Fq -- '--print' "$SCRIPT" || fail "hypr-usb-menu reconnect should support --print"

cat >"$TMP/bin/lsblk" <<'SH'
#!/usr/bin/env bash
cat <<'JSON'
{"blockdevices":[{"name":"sda","path":"/dev/sda","rm":true,"tran":"usb","hotplug":true,"fstype":"vfat","label":"ARCHIVE","mountpoints":["/run/media/osmarg/ARCHIVE"],"model":"BlockStore"}]}
JSON
SH
chmod +x "$TMP/bin/lsblk"

cat >"$TMP/bin/lsusb" <<'SH'
#!/usr/bin/env bash
cat <<'TXT'
Bus 001 Device 004: ID 1234:abcd USB Headset
Bus 001 Device 005: ID 0781:5567 SanDisk Cruzer Blade
TXT
SH
chmod +x "$TMP/bin/lsusb"

cat >"$TMP/bin/rofi" <<'SH'
#!/usr/bin/env bash
if [ "${ROFI_MODE:-}" = "nickname-device" ]; then
  printf '%s\n' 'USB Headset  1-4  1234:abcd'
elif [ "${ROFI_MODE:-}" = "nickname-value" ]; then
  printf '%s\n' 'Audifonos USB'
elif [ "${ROFI_MODE:-}" = "nickname-empty-bus" ]; then
  if printf '%s ' "$@" | grep -Fq 'Nombre USB'; then
    printf '%s\n' 'NoBusName'
  else
    printf '%s\n' 'USB Headset  1234:abcd'
  fi
elif [ "${ROFI_MODE:-}" = "reconnect" ]; then
  input="$(cat)"
  printf '%s\n' "$input" >"$HYPR_USB_TEST_TMP/reconnect-menu.log"
  printf '%s\n' "$input" | grep -F '1-4' | head -n1
else
  printf '%s\n' 'FLASH  /dev/sda  storage'
fi
SH
chmod +x "$TMP/bin/rofi"

for cmd in notify-send xdg-open nautilus udisksctl; do
  cat >"$TMP/bin/$cmd" <<'SH'
#!/usr/bin/env bash
echo "$(basename "$0") $*" >>"$CALLS"
SH
  chmod +x "$TMP/bin/$cmd"
done

export PATH="$TMP/bin:$PATH" CALLS XDG_STATE_HOME="$TMP/state" XDG_CONFIG_HOME="$TMP/config"
export HYPR_SYS_ROOT="$TMP/sys"
export HYPR_USB_SYS_ROOT="$HYPR_SYS_ROOT/bus/usb/devices"
mkdir -p "$HYPR_USB_SYS_ROOT/1-4" "$HYPR_USB_SYS_ROOT/1-5" "$HYPR_SYS_ROOT/block/sda"
ln -s "$HYPR_USB_SYS_ROOT/1-5" "$HYPR_SYS_ROOT/block/sda/device"
printf '1234' >"$HYPR_USB_SYS_ROOT/1-4/idVendor"
printf 'abcd' >"$HYPR_USB_SYS_ROOT/1-4/idProduct"
printf 'HeadsetCo' >"$HYPR_USB_SYS_ROOT/1-4/manufacturer"
printf 'USB Headset' >"$HYPR_USB_SYS_ROOT/1-4/product"
printf '0781' >"$HYPR_USB_SYS_ROOT/1-5/idVendor"
printf '5567' >"$HYPR_USB_SYS_ROOT/1-5/idProduct"
printf 'SanDisk' >"$HYPR_USB_SYS_ROOT/1-5/manufacturer"
printf 'Cruzer Blade' >"$HYPR_USB_SYS_ROOT/1-5/product"

ROFI_MODE=nickname-empty-bus bash "$SCRIPT" nickname --print >/dev/null 2>&1 || true
if [ -f "$TMP/config/orgm-hypr/usb-names.tsv" ] && grep -Fq $'1234:abcd\tNoBusName' "$TMP/config/orgm-hypr/usb-names.tsv"; then
  fail "nickname must not save when selected bus id is empty"
fi

nickname_output="$(ROFI_MODE=nickname-device "$SCRIPT" nickname --print)"
[ -f "$TMP/config/orgm-hypr/usb-names.tsv" ] || fail "nickname file missing"
grep -Fq $'1234:abcd\tAudifonos USB' "$TMP/config/orgm-hypr/usb-names.tsv" || fail "nickname not saved"
grep -Fq 'unbind 1-4' <<<"$nickname_output" || fail "nickname print should unbind selected headset bus id"
grep -Fq 'bind 1-4' <<<"$nickname_output" || fail "nickname print should bind selected headset bus id"

reconnect_output="$(ROFI_MODE=reconnect bash "$SCRIPT" reconnect --print)"
grep -Fq 'unbind 1-4' <<<"$reconnect_output" || fail "reconnect print should target headset bus id"
grep -Fq 'bind 1-4' <<<"$reconnect_output" || fail "reconnect print should bind headset bus id"
if grep -Fq '1-5' <<<"$reconnect_output"; then fail "reconnect print must not target storage bus id"; fi
if grep -Fq '1-5' "$TMP/reconnect-menu.log"; then fail "reconnect menu must not offer storage bus id"; fi

ROFI_MODE=storage bash "$SCRIPT" open
if grep -q 'unbind' "$CALLS"; then fail "storage flow must not unbind"; fi

bash "$SCRIPT" status | jq -e '.text and .tooltip and (.class | index("usb"))' >/dev/null || fail "status JSON invalid"

echo "hypr usb menu smoke test passed"
