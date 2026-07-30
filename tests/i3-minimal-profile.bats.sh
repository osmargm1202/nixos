#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
DOTFILES_MODULE="$ROOT/nixos/common-dotfiles.nix"
MANIFEST="$ROOT/dotfiles/config/dotfiles.json"
I3_ROOT="$ROOT/dotfiles/config/profiles/i3"
I3_CONFIG="$I3_ROOT/.config/i3/config"
I3STATUS_WRAPPER="$I3_ROOT/.local/bin/i3status-localized"
COMMON="$ROOT/nixos/common.nix"
FLATPAK="$ROOT/nixos/flatpak.nix"
ZEN="$ROOT/nixos/zen-browser.nix"
MK_SYSTEM="$ROOT/lib/mk-system.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for forbidden in conky waybar polybar eww i3blocks; do
  if grep -Eqi "$forbidden" "$PROFILE" "$I3_CONFIG"; then
    fail "i3 profile still references $forbidden"
  fi
  if grep -REqi "$forbidden" "$I3_ROOT"; then
    fail "i3 dotfile tree still references $forbidden"
  fi
done

grep -Eq '^[[:space:]]+i3status[[:space:]]*$' "$PROFILE" ||
  fail 'NixOS i3 integration must install i3status'
grep -Fq 'bar {' "$I3_CONFIG" || fail 'native i3bar is missing'
grep -Fq 'status_command ~/.local/bin/i3status-localized' "$I3_CONFIG" ||
  fail 'native i3bar must use the localized i3status wrapper'
grep -Fq 'subprocess.Popen(' "$I3STATUS_WRAPPER" &&
  grep -Eq '^[[:space:]]*\[[[:space:]]*"i3status"[[:space:]]*,' "$I3STATUS_WRAPPER" ||
  fail 'localized i3status wrapper must execute i3status'
! grep -Eq 'i3bar_command|tray_output|font pango:.*bar' "$I3_CONFIG" ||
  fail 'i3bar must not carry custom bar settings'

grep -Fq '++ lib.optionals (!isMinimalDesktop) [ ../nixos/ai/default.nix ]' "$MK_SYSTEM" ||
  fail 'minimal desktop must exclude the AI module'
grep -Fq 'services.hardware.openrgb.enable = !isMinimalDesktop;' "$COMMON" ||
  fail 'minimal desktop must disable OpenRGB'
grep -Fq 'virtualisation.podman = lib.mkIf (!isMinimalDesktop) {' "$COMMON" ||
  fail 'minimal desktop must exclude Podman and its socket'
grep -Fq '++ lib.optionals (inputs != null && !isMinimalDesktop) [ ./webapps.nix ]' "$COMMON" ||
  fail 'minimal desktop must exclude webapps'
grep -Fq 'systemd.user.services.picom = lib.mkIf (!isMinimalDesktop) {' "$PROFILE" ||
  fail 'minimal i3 must not install the Picom user service'
for session_switch in I3_START_PICOM I3_START_DISCORD; do
  grep -Fq "$session_switch = if isMinimalDesktop then \"0\" else \"1\";" "$PROFILE" ||
    fail "$session_switch must be 0 for minimal i3 and 1 for normal i3"
done
grep -Fq '[ "$I3_START_PICOM" = 0 ] && exit 0; exec systemctl --user start picom.service' "$I3_CONFIG" ||
  fail 'i3 must only attempt Picom startup when its session switch is enabled'
grep -Fq '[ "$I3_START_DISCORD" = 0 ] && exit 0; exec i3-start-discord-background' "$I3_CONFIG" ||
  fail 'i3 must only attempt Discord startup when its session switch is enabled'
grep -Fq 'systemd.user.services.i3-clipcat = {' "$PROFILE" ||
  fail 'minimal i3 must retain the Clipcat user service'
grep -Eq '^[[:space:]]+clipcat[[:space:]]*$' "$PROFILE" ||
  fail 'minimal i3 must retain Clipcat'

desktop_imports="$(sed -n '/imports = lib.optionals (!isMinimalDesktop) \[/,/^  \];/p' "$PROFILE")"
grep -Fq 'imports = lib.optionals (!isMinimalDesktop) [' <<<"$desktop_imports" ||
  fail 'minimal i3 must conditionally omit desktop-only imports'
for module in ./printer.nix ./vesktop.nix; do
  grep -Fq "$module" <<<"$desktop_imports" ||
    fail "minimal i3 must omit $module through the desktop-only import guard"
done
grep -Fq 'services.flatpak = {' "$FLATPAK" ||
  fail 'minimal i3 must retain Flatpak support'
grep -Fq 'packages = lib.optionals (!isMinimalDesktop) [' "$FLATPAK" ||
  fail 'minimal i3 must omit declared Flatpak applications'
grep -Fq 'lib.optionals (!isMinimalDesktop) [ zenBrowser ]' "$ZEN" ||
  fail 'minimal i3 must omit Zen Browser'
grep -Fq 'BROWSERS=(${if isMinimalDesktop then "chromium" else "zen chromium"})' "$ZEN" ||
  fail 'PSD must use Chromium for minimal i3 and retain Zen for normal i3'

grep -Fq 'minimalPackages ++ lib.optionals (!isMinimalDesktop) desktopOnlyPackages;' "$COMMON" ||
  fail 'minimal desktop packages must be separated from desktop-only packages'
minimal_packages="$(sed -n '/minimalPackages = with pkgs; \[/,/^  \];/p' "$COMMON")"
grep -Eq '^[[:space:]]+python3[[:space:]]*$' <<<"$minimal_packages" ||
  fail 'minimal desktop must retain Python 3 for i3status-localized'
for excluded in nextcloud-client uv android-tools kdeconnect-kde freerdp podman-compose jujutsu gum steam-run vscode; do
  if grep -Fq "$excluded" <<<"$minimal_packages"; then
    fail "minimal desktop must not install $excluded"
  fi
done

for path in .config/conky .config/picom .config/polybar; do
  [ ! -e "$I3_ROOT/$path" ] || fail "$path must be removed from i3 dotfiles"
  if grep -Fq "\"$path\"" "$DOTFILES_MODULE"; then
    fail "$path must not be deployed for i3"
  fi
done

for helper in i3-polybar i3-polybar-theme i3-gh0stzk-theme i3-polybar-launch i3-status-battery i3-status-cpu-temp i3-status-gpu-temp; do
  [ ! -e "$I3_ROOT/.local/bin/$helper" ] || fail "$helper must be removed"
  if grep -Fq "\".local/bin/$helper\"" "$DOTFILES_MODULE"; then
    fail "$helper must not be deployed"
  fi
done

jq -e '
  all(.shared.paths[]; . != ".config/conky" and . != ".config/picom" and . != ".config/polybar")
' "$MANIFEST" >/dev/null || fail 'obsolete i3 desktop paths remain in dotfiles manifest'

printf 'PASS: i3 uses native i3bar through the localized i3status wrapper\n'
