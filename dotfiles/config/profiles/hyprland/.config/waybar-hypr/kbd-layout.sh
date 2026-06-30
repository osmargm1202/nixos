#!/bin/sh

layout=""

if command -v swaymsg >/dev/null 2>&1 && [ -n "${SWAYSOCK:-}" ]; then
  layout=$(swaymsg -t get_inputs 2>/dev/null \
    | awk -F'"' '/"xkb_active_layout_name"/ { print $4; exit }')
fi

if [ -z "$layout" ] && command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  layout=$(hyprctl devices 2>/dev/null | awk -F': ' '
    /active keymap:/ { current=$2 }
    /main: yes/ { print current; exit }
  ')
fi

case "$layout" in
  *Spanish*Latin*|*latam*|*Latam*) text="LATAM" ;;
  *English*|*US*|*us*) text="US" ;;
  "") text="--" ;;
  *) text=$(printf '%s' "$layout" | tr '[:lower:]' '[:upper:]' | awk '{ print $1 }') ;;
esac

printf '%s\n' "$text"
