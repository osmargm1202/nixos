#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The shared manager resolves render-node to `windows` and Lenovo VFIO to
# `lenovo-windows`; each compositor must invoke that one resolver.
grep -Fqx 'bindsym $mod+Ctrl+w exec --no-startup-id windows-rdp toggle' \
  "$repo_dir/dotfiles/config/profiles/i3/.config/i3/config"
grep -Fqx '  hl.bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd("windows-rdp toggle"))' \
  "$repo_dir/dotfiles/config/profiles/hyprland/.config/hypr/lua/keybindings.lua"
grep -Fqx '        <command>windows-rdp toggle</command>' \
  "$repo_dir/dotfiles/config/profiles/labwc/.config/labwc/rc.xml"
printf 'windows-vm-shortcuts: ok\n'
