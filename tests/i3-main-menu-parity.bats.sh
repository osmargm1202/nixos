#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/.config/i3"
cat > "$tmp/bin/i3-rofi" <<'EOF'
#!/usr/bin/env bash
cat > "$MENU_CAPTURE"
[[ -n "${MENU_CHOICE:-}" ]] || exit 1
printf '%s\n' "$MENU_CHOICE"
EOF
chmod +x "$tmp/bin/i3-rofi"
helper="$ROOT/dotfiles/config/profiles/i3/.local/bin/i3-main-menu"
HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" PATH="$tmp/bin:$PATH" \
  MENU_CAPTURE="$tmp/jarq-menu" "$helper"
cp "$ROOT/dotfiles/config/users/osmarg/profiles/i3/.config/i3/main-menu.conf" "$tmp/home/.config/i3/main-menu.conf"
HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" PATH="$tmp/bin:$PATH" \
  MENU_CAPTURE="$tmp/osmarg-menu" "$helper"
python3 - "$tmp/jarq-menu" "$tmp/osmarg-menu" <<'PY'
from pathlib import Path
import sys
jarq = set(Path(sys.argv[1]).read_text().splitlines())
osmarg = set(Path(sys.argv[2]).read_text().splitlines())
daily = {"Apps", "Windows", "Terminal", "Files", "Calculator", "Clipboard", "Devices", "Help", "Power"}
assert daily <= jarq, ("missing daily Jarq controls", daily - jarq)
assert daily <= osmarg, ("missing daily Osmarg controls", daily - osmarg)
assert {"SSH", "AI", "Pi", "Obsidian", "Profile"}.isdisjoint(jarq), ("personal items leaked into Jarq", jarq)
assert {"SSH", "Obsidian", "Profile"} <= osmarg, ("Osmarg lost personal menu entries", osmarg)
print("PASS: rendered i3 menus retain daily controls and separate personal entries")
PY

for command in orgm-visual-profile i3-wallpaper; do
  cat > "$tmp/bin/$command" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "${0##*/}" "$*" > "$ACTION_CAPTURE"
EOF
  chmod +x "$tmp/bin/$command"
done
HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" PATH="$tmp/bin:$PATH" \
  MENU_CAPTURE="$tmp/menu" MENU_CHOICE=Wallpaper ACTION_CAPTURE="$tmp/action" "$helper"
grep -Fxq 'orgm-visual-profile random-wallpaper' "$tmp/action"
rm "$tmp/home/.config/i3/main-menu.conf"
HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" PATH="$tmp/bin:$PATH" \
  MENU_CAPTURE="$tmp/menu" MENU_CHOICE=Wallpaper ACTION_CAPTURE="$tmp/action" "$helper"
grep -Fxq 'i3-wallpaper --random' "$tmp/action"
printf '%s\n' 'PASS: personal wallpaper action overrides the shared menu action'
