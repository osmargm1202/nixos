export LC_ALL=C

mute_usb_monitors() {
  local sources source mute
  sources=$(pactl list short sources) || return 0
  while read -r _ source _; do
    case "$source" in
      alsa_output.usb-*.monitor)
        # The sink monitor exposes playback as a separate recording source.
        mute=$(pactl get-source-mute "$source") || continue
        if [[ $mute == 'Mute: no' ]]; then
          pactl set-source-mute "$source" 1 || true
        fi
        ;;
    esac
  done <<< "$sources"
}

coproc subscription { exec pactl subscribe; }
subscription_fd=${subscription[0]}
mute_usb_monitors
while IFS= read -r -u "$subscription_fd" event; do
  case "$event" in
    "Event 'new' on source #"*|"Event 'change' on source #"*)
      mute_usb_monitors
      ;;
  esac
done
