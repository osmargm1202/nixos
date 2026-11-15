# The display manager must start Xorg before invoking this session.
test -n "${DISPLAY:-}" || { echo 'Select i3 ligero (X11) at login.' >&2; exit 1; }
test -r "${I3_LIGHT_CONFIG:?Missing i3 configuration}"
restore_environment=()
clear_environment=()
managed_environment=(WAYLAND_DISPLAY WAYLAND_SOCKET HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK
  NIXOS_OZONE_WL MOZ_ENABLE_WAYLAND CLUTTER_BACKEND ELECTRON_OZONE_PLATFORM_HINT
  XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE GDK_BACKEND QT_QPA_PLATFORM SDL_VIDEODRIVER)
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
  systemctl --user stop orgm-i3-light-session.target graphical-session.target || true
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
unset WAYLAND_DISPLAY WAYLAND_SOCKET HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK NIXOS_OZONE_WL
unset MOZ_ENABLE_WAYLAND CLUTTER_BACKEND
export XDG_CURRENT_DESKTOP=i3 XDG_SESSION_DESKTOP=i3 XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb SDL_VIDEODRIVER=x11 ELECTRON_OZONE_PLATFORM_HINT=x11
dbus-update-activation-environment WAYLAND_DISPLAY= WAYLAND_SOCKET= HYPRLAND_INSTANCE_SIGNATURE= SWAYSOCK= NIXOS_OZONE_WL= MOZ_ENABLE_WAYLAND= CLUTTER_BACKEND=
# Empty Wayland values still satisfy ConditionEnvironment=NAME. Unset them
# after D-Bus synchronization so Wayland-only services cannot activate in i3.
systemctl --user unset-environment WAYLAND_DISPLAY WAYLAND_SOCKET HYPRLAND_INSTANCE_SIGNATURE SWAYSOCK NIXOS_OZONE_WL MOZ_ENABLE_WAYLAND CLUTTER_BACKEND
dbus-update-activation-environment --systemd DISPLAY XAUTHORITY XDG_SESSION_TYPE XDG_SESSION_DESKTOP XDG_CURRENT_DESKTOP GDK_BACKEND QT_QPA_PLATFORM SDL_VIDEODRIVER ELECTRON_OZONE_PLATFORM_HINT
systemctl --user start orgm-i3-light-session.target
i3 -c "$I3_LIGHT_CONFIG" &
wm_pid=$!
wait "$wm_pid"
