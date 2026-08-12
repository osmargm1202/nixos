#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

nix eval --impure --raw --expr '
  let
    flake = builtins.getFlake (toString ./.) ;
    profileNames = [ "lenovo-gnome" "lenovo-labwc" "lenovo-hyprland" "lenovo-i3" ];
    configs = builtins.map (name: flake.nixosConfigurations.${name}.config) profileNames;
    hasTtyAutologin = config:
      builtins.any (line: builtins.match ".*--autologin osmarg.*" line != null)
        config.systemd.services."getty@tty1".serviceConfig.ExecStart
      && builtins.any (line: builtins.match ".*--autologin osmarg.*" line != null)
        config.systemd.services."autovt@tty1".serviceConfig.ExecStart;
    hasAutologin = config:
      config.services.displayManager.autoLogin.enable
      && config.services.displayManager.autoLogin.user == "osmarg"
      && hasTtyAutologin config;
    hasBootMenu = config:
      config.boot.loader.systemd-boot.configurationLimit == 3
      # systemd-boot renders each specialisation key as NixOS (<key>).
      && builtins.attrNames config.specialisation == [ "battery" "gaming" "server" "windows-vfio" ]
      # Explicit sort keys put the current generation in the requested order.
      && config.boot.loader.systemd-boot.sortKey == "nixos-01-normal"
      && config.specialisation.windows-vfio.configuration.boot.loader.systemd-boot.sortKey == "nixos-00-windows-vfio"
      && config.specialisation.gaming.configuration.boot.loader.systemd-boot.sortKey == "nixos-02-gaming"
      && config.specialisation.battery.configuration.boot.loader.systemd-boot.sortKey == "nixos-03-battery"
      && config.specialisation.server.configuration.boot.loader.systemd-boot.sortKey == "nixos-04-server"
      && builtins.match ".*/bin/set-vfio-boot-default"
        config.boot.loader.systemd-boot.extraInstallCommands != null
      && config.specialisation.gaming.configuration.orgm.gaming.gamescopeTty1.enable
      && !config.specialisation.gaming.configuration.services.displayManager.sddm.enable
      && builtins.match ".*gamescope -e -- steam -gamepadui.*"
        config.specialisation.gaming.configuration.programs.bash.loginShellInit != null
      && config.specialisation.server.configuration.systemd.defaultUnit == "multi-user.target"
      && config.specialisation.server.configuration.services.openssh.enable
      && config.specialisation.server.configuration.networking.networkmanager.enable
      && !config.specialisation.server.configuration.services.xserver.enable
      && !hasTtyAutologin config.specialisation.server.configuration;
  in
    if builtins.all (config: hasAutologin config && hasBootMenu config) configs
    then "Lenovo boot specialisations: ok"
    else throw "Lenovo boot specialisation menu is incomplete"
'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
boot_root="$tmp/boot"
mkdir -p "$boot_root/loader/entries"
cat >"$boot_root/loader/loader.conf" <<'EOF'
timeout 5
default nixos-generation-999.conf
editor no
EOF
touch "$boot_root/loader/entries/nixos-generation-999.conf"
touch "$boot_root/loader/entries/nixos-generation-999-specialisation-windows-vfio.conf"

# This is exactly the executable embedded in extraInstallCommands. Give it a
# private ESP-shaped tree and assert the post-install default it writes.
nix build --no-link .#nixosConfigurations.lenovo-i3.config.system.build.installBootLoader
install_hook="$(nix eval --raw .#nixosConfigurations.lenovo-i3.config.boot.loader.systemd-boot.extraInstallCommands)"
SYSTEMD_BOOT_ROOT="$boot_root" "$install_hook"
grep -Fxq 'default nixos-generation-999-specialisation-windows-vfio.conf' \
  "$boot_root/loader/loader.conf"

printf '%s\n' 'PASS: Lenovo boot default selects the matching Windows VFIO entry'
