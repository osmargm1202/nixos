# Invoked by the packaged launcher; never source this from an existing desktop.
test -n "${DISPLAY:-}" || { echo 'Select i3 (X11) from the login screen.' >&2; exit 1; }
restore_environment=()
clear_environment=()
managed_environment=(WAYLAND_DISPLAY WAYLAND_SOCKET HYPRLAND_INSTANCE_SIGNATURE NIXOS_OZONE_WL
  MOZ_ENABLE_WAYLAND CLUTTER_BACKEND ELECTRON_OZONE_PLATFORM_HINT XDG_CURRENT_DESKTOP
  XDG_SESSION_DESKTOP XDG_SESSION_TYPE GDK_BACKEND QT_QPA_PLATFORM SDL_VIDEODRIVER)
for name in "${managed_environment[@]}"; do
  if [[ -v "$name" ]]; then
    restore_environment+=("$name=${!name}")
  else
    clear_environment+=("$name")
  fi
done
wm_pid=''
cleanup() {
  trap - EXIT HUP INT TERM
  if [[ -n "$wm_pid" ]] && kill -0 "$wm_pid" 2>/dev/null; then
    kill "$wm_pid"
    wait "$wm_pid" || true
  fi
  systemctl --user stop orgm-i3-session.target graphical-session.target || true
  if ((${#restore_environment[@]})); then
    dbus-update-activation-environment --systemd "${restore_environment[@]}" || true
  fi
  for name in "${clear_environment[@]}"; do
    dbus-update-activation-environment "$name=" || true
    systemctl --user unset-environment "$name" || true
  done

}
trap cleanup EXIT
trap 'exit 0' HUP INT TERM

# Hyprland's profile exports Wayland globally. Correct this session and its
# D-Bus activation environment, without changing Hyprland's configuration.
unset WAYLAND_DISPLAY WAYLAND_SOCKET HYPRLAND_INSTANCE_SIGNATURE NIXOS_OZONE_WL
unset MOZ_ENABLE_WAYLAND CLUTTER_BACKEND ELECTRON_OZONE_PLATFORM_HINT
export XDG_CURRENT_DESKTOP=i3 XDG_SESSION_DESKTOP=i3 XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb SDL_VIDEODRIVER=x11
export ELECTRON_OZONE_PLATFORM_HINT=x11
systemctl --user unset-environment WAYLAND_DISPLAY WAYLAND_SOCKET HYPRLAND_INSTANCE_SIGNATURE NIXOS_OZONE_WL MOZ_ENABLE_WAYLAND CLUTTER_BACKEND
dbus-update-activation-environment WAYLAND_DISPLAY= WAYLAND_SOCKET= HYPRLAND_INSTANCE_SIGNATURE= NIXOS_OZONE_WL= MOZ_ENABLE_WAYLAND= CLUTTER_BACKEND=
dbus-update-activation-environment --systemd DISPLAY XAUTHORITY XDG_SESSION_TYPE XDG_SESSION_DESKTOP XDG_CURRENT_DESKTOP GDK_BACKEND QT_QPA_PLATFORM SDL_VIDEODRIVER ELECTRON_OZONE_PLATFORM_HINT
systemctl --user start orgm-i3-session.target
i3 -c "${ORGM_I3_CONFIG:?Missing ORGM i3 configuration}" &
wm_pid=$!
wait "$wm_pid"
