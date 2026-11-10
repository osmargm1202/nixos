# Small dmenu interface used by Osmarg's desktop scripts, implemented with GTK.
# Unsupported Rofi options fail explicitly rather than changing their meaning.
set -euo pipefail
prompt=Seleccionar
password=0
index_output=0
strict=0
while (($#)); do
  case "$1" in
    -dmenu|-i) shift ;;
    -p) prompt="${2:?Missing prompt}"; shift 2 ;;
    -password) password=1; shift ;;
    -no-custom|-only-match) strict=1; shift ;;
    -format) [[ "${2:-}" == i ]] || exit 2; index_output=1; shift 2 ;;
    *) printf 'orgm-menu: unsupported option: %s\n' "$1" >&2; exit 2 ;;
  esac
done
mapfile -t items
# Empty stdin means a free-text prompt, not a list containing an empty choice.
if ((${#items[@]} == 0)) || { ((${#items[@]} == 1)) && [[ -z ${items[0]} ]]; }; then
  ((strict == 0 && index_output == 0)) || exit 1
  entry=(zenity --entry --no-markup --title="$prompt" --text="$prompt")
  ((password == 0)) || entry+=(--hide-text)
  exec "${entry[@]}"
fi
((password == 0)) || exit 2
# Feed labels over stdin, not argv. Hidden row IDs preserve tabs, duplicates,
# punctuation and clipboard payloads without interpreting them as commands.
selected=$(
  for i in "${!items[@]}"; do
    printf '%s\n%s\n' "$i" "${items[$i]//$'\t'/    }"
  done | zenity --list --no-markup --title="$prompt" --width=600 --height=420 \
    --column=ID --column=Opción --hide-column=1 --print-column=1 --hide-header
) || exit 1
[[ "$selected" =~ ^[0-9]+$ ]] || exit 1
((selected < ${#items[@]})) || exit 1
if ((index_output)); then printf '%s\n' "$selected"; else printf '%s\n' "${items[$selected]}"; fi
