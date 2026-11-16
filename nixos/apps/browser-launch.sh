case "${1:-}" in
  --focus|--restore-or-focus)
    if [[ "${XDG_CURRENT_DESKTOP:-}" == *Hyprland* ]]; then
      address="$(hyprctl -j clients | jq -r '[.[] | select(.class == "brave-origin")] | sort_by(.focusHistoryID) | .[0].address // empty')"
      if [[ -n "$address" ]]; then
        exec hyprctl dispatch "hl.dsp.focus({ window = \"address:$address\" })"
      fi
    elif [[ "${XDG_CURRENT_DESKTOP:-}" == *i3* ]]; then
      # Main browser windows only: URL-app windows share Brave's process but
      # have different WM_CLASS values and must not satisfy Win+W.
      identifier="$(i3-msg -t get_tree 2>/dev/null | jq -r '
        [.. | objects | select(.window? != null)
          | select(((.window_properties.class? // "") | ascii_downcase) == "brave-origin")]
        | sort_by(.focused) | reverse | .[0].id // empty')" || identifier=''
      if [[ "$identifier" =~ ^[0-9]+$ ]] &&
        i3-msg "[con_id=$identifier] focus" | jq -e 'length > 0 and all(.[]; .success == true)' >/dev/null; then
        exit 0
      fi
    fi
    shift ;;
  --new|--new-tab) shift ;;
esac
if [[ "${1:-}" == --prompt ]]; then
  shift
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
    url="$("$ORGM_BROWSER_ZENITY" --entry --title='Abrir web' --text='Dirección o búsqueda')" || exit 0
  else
    url="$("$HOME/.local/bin/orgm-rofi" -dmenu -i -p 'Abrir web')" || exit 0
  fi
  [[ -n "$url" ]] || exit 0
  set -- "$url" "$@"
fi
exec "$ORGM_BROWSER_EXECUTABLE" "$@"
