#!/usr/bin/env bash
set -euo pipefail

# orgm-visual-profile holds its state lock while it calls i3-wallpaper, which
# calls back into orgm-visual-profile. Those nested calls must not deadlock.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USERS="$ROOT/dotfiles/config/users"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

check_user() {
  local user="$1" profile wrapper home bin
  case "$user" in
    osmarg) profile="$USERS/osmarg/programs/orgm/.local/bin/orgm-visual-profile" ;;
    *) profile="$USERS/$user/profiles/i3/.local/bin/orgm-visual-profile" ;;
  esac
  wrapper="$USERS/$user/profiles/i3/.local/bin/i3-wallpaper"
  [[ -x "$profile" && -x "$wrapper" ]] || fail "$user: i3 visual profile helpers missing"

  home="$TMP/$user/home"
  bin="$TMP/$user/bin"
  mkdir -p "$bin" "$home/Pictures/orgm"
  printf 'png' >"$home/Pictures/orgm/a.png"
  ln -s "$profile" "$bin/orgm-visual-profile"
  ln -s "$wrapper" "$bin/i3-wallpaper"
  # Mirrors i3-wallpaper-base: store the selection, then report it back.
  cat >"$bin/i3-wallpaper-base" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
selected="$(find "$I3_WALLPAPER_DIR" -type f -print -quit)"
mkdir -p "$XDG_STATE_HOME/i3"
printf '%s\n' "$selected" >"$XDG_STATE_HOME/i3/wallpaper"
if [[ -n "${I3_WALLPAPER_RECORD_COMMAND:-}" ]]; then
  "$I3_WALLPAPER_RECORD_COMMAND" record-wallpaper "$selected"
fi
EOF
  printf '#!/bin/sh\nexit 0\n' >"$bin/i3-msg"
  chmod +x "$bin/i3-wallpaper-base" "$bin/i3-msg"

  env -i PATH="$bin:/run/current-system/sw/bin:/usr/bin:/bin" HOME="$home" \
    XDG_STATE_HOME="$TMP/$user/state" XDG_CONFIG_HOME="$home/.config" \
    ORGM_VISUAL_PROFILE_BACKEND=i3 \
    timeout 15 orgm-visual-profile random-wallpaper ||
    fail "$user: random-wallpaper deadlocked or failed"

  grep -qx "$home/Pictures/orgm/a.png" "$TMP/$user/state/orgm-visual-profile/profiles/orgm/wallpaper" ||
    fail "$user: random wallpaper was not recorded in the profile"

  env -i PATH="$bin:/run/current-system/sw/bin:/usr/bin:/bin" HOME="$home" \
    XDG_STATE_HOME="$TMP/$user/state" XDG_CONFIG_HOME="$home/.config" \
    ORGM_VISUAL_PROFILE_BACKEND=i3 \
    timeout 15 i3-wallpaper --random ||
    fail "$user: direct i3-wallpaper call deadlocked or failed"
}

for user in osmarg jarq; do
  check_user "$user"
done

printf 'PASS: i3 wallpaper helpers re-enter the visual profile lock without deadlock\n'
