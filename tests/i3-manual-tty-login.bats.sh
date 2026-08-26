#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/nixos/profiles/i3.nix"
CONFIG="$ROOT/dotfiles/config/profiles/i3/.config/i3/config"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

if grep -Fq 'services.getty.autologinUser' "$PROFILE"; then
  fail 'i3 must require username/password at the TTY'
fi
if grep -Fq './sddm.nix' "$PROFILE"; then
  fail 'i3 must not import SDDM'
fi
if grep -Fq 'services.displayManager.defaultSession' "$PROFILE"; then
  fail 'i3 starts through StartX and must not configure a display-manager session'
fi
grep -Fq 'services.displayManager.autoLogin.enable = lib.mkForce false;' "$PROFILE" ||
  fail 'i3 must not activate the display-manager autologin unit'
nix eval --impure --raw --expr '
  let
    config = (builtins.getFlake (toString ./.)).nixosConfigurations.lenovo-i3.config;
    commands = builtins.concatLists [
      config.systemd.services."getty@tty1".serviceConfig.ExecStart
      config.systemd.services."autovt@tty1".serviceConfig.ExecStart
    ];
  in
    if builtins.any (command: builtins.match ".*--autologin.*" command != null) commands
    then throw "lenovo-i3 still autologins tty1"
    else "manual tty1 login"
' >/dev/null || fail 'lenovo-i3 must not autologin tty1'
grep -Fq 'if [ "$(tty)" = /dev/tty1 ] && [ -z "$DISPLAY" ]; then' "$PROFILE" ||
  fail 'manual tty1 login must start i3 through startx'
grep -Fq 'exec startx /etc/X11/xinit/xinitrc' "$PROFILE" ||
  fail 'tty1 login does not enter the configured i3 X session'
if grep -Fq 'i3-startx-attempted' "$PROFILE"; then
  fail 'stale marker must not block a later authenticated login retry'
fi
grep -Fq 'security.pam.services.login.enableGnomeKeyring = true;' "$PROFILE" ||
  fail 'PAM login must unlock GNOME Keyring with the TTY password'
if grep -Fq 'gnome-keyring-daemon --start' "$CONFIG"; then
  fail 'i3 startup must not duplicate the PAM-managed keyring daemon'
fi

printf 'PASS: password-authenticated tty1 login starts i3 and unlocks keyring\n'
