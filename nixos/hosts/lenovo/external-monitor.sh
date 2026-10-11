# Boot/TTY policy is video=eDP-1:d in the Lenovo base. The desktop owns
# hotplug; this helper repairs a live layout without a VT/session restart.
case "${1:---apply}" in
  --status)
    for connector in /sys/class/drm/card*-*/status; do
      [[ -f "$connector" ]] || continue
      name="${connector%/status}"
      printf '%s: %s\n' "${name##*/}" "$(<"$connector")"
    done
    printf 'Kernel: %s\n' "$(</proc/cmdline)"
    exit 0
    ;;
  --apply) ;;
  *) printf '%s\n' 'Usage: lenovo-external-monitor [--apply|--status]' >&2; exit 2 ;;
esac

# A host terminal/agent may not inherit the compositor's environment. Resolve
# a single Hyprland session without changing VTs or guessing an instance.
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null; then
  instances="$(hyprctl instances -j 2>/dev/null)" || instances='[]'
  signature="$(jq -r 'if length == 1 then .[0].instance else empty end' <<<"$instances")"
  if [[ -n "$signature" ]]; then export HYPRLAND_INSTANCE_SIGNATURE="$signature"; fi
fi

# Use Ryoku's output API when present; it also publishes the greeter's main
# monitor and preserves modes/scaling owned by Hub > Displays.
if command -v ryoku-hub >/dev/null && outputs="$(ryoku-hub outputs list 2>/dev/null)"; then
  layout="$(jq -ce '
    def internal: test("^(eDP|LVDS|DSI)(-|[0-9])");
    [.[] | select(.name | internal | not)] as $external
    | if ($external | length) == 0 then error("No external monitor connected") else . end
    | ([$external[] | select(.disabled | not)] | if length > 0 then . else $external end) as $active
    | ($active | map(select(.focused)) | if length > 0 then .[0] else $active[0] end) as $main
    | map({name, enabled: ((.name | internal | not) and ((.disabled | not) or .name == $main.name)),
           mode: (if .disabled then "" else .mode end), scale, transform, vrr, mirror, colorMode, sdrBrightness,
           x: (if .disabled then 0 else .x - $main.x end),
           y: (if .disabled then 0 else .y - $main.y end)})
  ' <<<"$outputs")"
  exec ryoku-hub outputs apply "$layout"
fi

# Other Lenovo desktop profiles keep their own native display backend.
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  outputs="$(hyprctl monitors all -j)"
  changes="$(jq -er '
    def internal: test("^(eDP|LVDS|DSI)(-|[0-9])");
    [.[] | select(.name | internal | not)] as $external
    | if ($external | length) == 0 then error("No external monitor connected") else . end
    | ([.[] | select(.name | internal) | "hl.monitor({ output = " + (.name | tojson) + ", disabled = true })"]
       + (if any($external[]; .disabled | not) then [] else
          ["hl.monitor({ output = " + ($external[0].name | tojson) + ", mode = \"preferred\", position = \"0x0\", scale = 1 })"] end))
    | join("; ")
  ' <<<"$outputs")"
  [[ -n "$changes" ]] || exit 0
  exec hyprctl eval "$changes"
fi

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  outputs="$(wlr-randr --json)"
  mapfile -t external < <(jq -r '.[] | select(.name | test("^(eDP|LVDS|DSI)(-|[0-9])") | not) | .name' <<<"$outputs")
  ((${#external[@]})) || { printf '%s\n' 'No external monitor connected' >&2; exit 1; }
  args=(--output "${external[0]}" --on --preferred --pos "0,0")
  mapfile -t internal < <(jq -r '.[] | select(.name | test("^(eDP|LVDS|DSI)(-|[0-9])")) | .name' <<<"$outputs")
  for name in "${internal[@]}"; do args+=(--output "$name" --off); done
  exec wlr-randr "${args[@]}"
elif [[ -n "${DISPLAY:-}" ]]; then
  outputs="$(xrandr --query)"
  external=()
  internal=()
  while read -r name state _; do
    [[ "$state" == connected ]] || continue
    if [[ "$name" =~ ^(eDP|LVDS|DSI)(-|[0-9]) ]]; then internal+=("$name"); else external+=("$name"); fi
  done <<<"$outputs"
  ((${#external[@]})) || { printf '%s\n' 'No external monitor connected' >&2; exit 1; }
  args=(--output "${external[0]}" --auto --primary --pos 0x0)
  for name in "${internal[@]}"; do args+=(--output "$name" --off); done
  exec xrandr "${args[@]}"
fi

printf '%s\n' 'No graphical session. The external console policy takes effect at boot.' >&2
exit 1
