#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

nix eval --impure --raw --expr '
  let
    flake = builtins.getFlake "path:${toString ./.}" ;
    profileNames = [ "lenovo-gnome" "lenovo-labwc" "lenovo-hyprland" "lenovo-i3" "lenovo-ryoku" ];
    configs = builtins.map (name: (import ./tests/fixtures/legacy-configurations.nix).${name}.config) profileNames
      ++ [ flake.nixosConfigurations.lenovo.config ];
    i3 = (import ./tests/fixtures/legacy-configurations.nix).lenovo-i3.config;
    autologinConfigs = builtins.map (
      name: (import ./tests/fixtures/legacy-configurations.nix).${name}.config
    ) [ "lenovo-gnome" "lenovo-labwc" "lenovo-hyprland" ];
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
      && config.boot.loader.systemd-boot.sortKey == "nixos-02-normal"
      && config.specialisation.windows-vfio.configuration.boot.loader.systemd-boot.sortKey == "nixos-01-windows-vfio"
      && config.specialisation.gaming.configuration.boot.loader.systemd-boot.sortKey == "nixos-03-gaming"
      && config.specialisation.battery.configuration.boot.loader.systemd-boot.sortKey == "nixos-04-battery"
      && config.specialisation.server.configuration.boot.loader.systemd-boot.sortKey == "nixos-00-server"
      && config.environment.etc."orgm/desktop-profile".text == "normal\n"
      && config.specialisation.windows-vfio.configuration.environment.etc."orgm/desktop-profile".text == "windows\n"
      && config.specialisation.gaming.configuration.environment.etc."orgm/desktop-profile".text == "gaming\n"
      && config.specialisation.battery.configuration.environment.etc."orgm/desktop-profile".text == "battery\n"
      && config.specialisation.server.configuration.environment.etc."orgm/desktop-profile".text == "server\n"
      && builtins.match ".*/bin/set-server-boot-default"
        config.boot.loader.systemd-boot.extraInstallCommands != null
      && config.specialisation.gaming.configuration.orgm.gaming.gamescopeTty1.enable
      && !config.specialisation.gaming.configuration.services.displayManager.sddm.enable
      && !config.specialisation.gaming.configuration.services.xserver.displayManager.lightdm.enable
      && builtins.match ".*gamescope -e -- steam -gamepadui.*"
        config.specialisation.gaming.configuration.programs.bash.loginShellInit != null
      && config.specialisation.server.configuration.systemd.defaultUnit == "multi-user.target"
      && config.specialisation.server.configuration.services.openssh.enable
      && config.specialisation.server.configuration.networking.networkmanager.enable
      && !config.specialisation.server.configuration.services.xserver.enable
      && !config.specialisation.server.configuration.services.xserver.displayManager.lightdm.enable
      && !hasTtyAutologin config.specialisation.server.configuration;
  in
    if builtins.all hasBootMenu configs
      && builtins.all hasAutologin autologinConfigs
      && !i3.services.displayManager.autoLogin.enable
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
touch "$boot_root/loader/entries/nixos-generation-999-specialisation-server.conf"

# This is exactly the executable embedded in extraInstallCommands. Give it a
# private ESP-shaped tree and assert the post-install default it writes.
nix build --no-link "path:$repo_dir#nixosConfigurations.lenovo.config.system.build.installBootLoader"
install_hook="$(nix eval --raw "path:$repo_dir#nixosConfigurations.lenovo.config.boot.loader.systemd-boot.extraInstallCommands")"
SYSTEMD_BOOT_ROOT="$boot_root" "$install_hook"
grep -Fxq 'default nixos-generation-999-specialisation-server.conf' \
  "$boot_root/loader/loader.conf"

# Reapplying it and migrating an existing specialisation default are safe.
SYSTEMD_BOOT_ROOT="$boot_root" "$install_hook"
grep -Fxq 'default nixos-generation-999-specialisation-server.conf' "$boot_root/loader/loader.conf"
sed -i 's/^default .*/default nixos-generation-999-specialisation-windows-vfio.conf/' "$boot_root/loader/loader.conf"
SYSTEMD_BOOT_ROOT="$boot_root" "$install_hook"
grep -Fxq 'default nixos-generation-999-specialisation-server.conf' "$boot_root/loader/loader.conf"
rm "$boot_root/loader/entries/nixos-generation-999-specialisation-server.conf"
sed -i 's/^default .*/default nixos-generation-999.conf/' "$boot_root/loader/loader.conf"
SYSTEMD_BOOT_ROOT="$boot_root" "$install_hook"
grep -Fxq 'default nixos-generation-999.conf' "$boot_root/loader/loader.conf"
sed -i 's/^default .*/default windows.conf/' "$boot_root/loader/loader.conf"
SYSTEMD_BOOT_ROOT="$boot_root" "$install_hook"
grep -Fxq 'default windows.conf' "$boot_root/loader/loader.conf"

printf '%s\n' 'PASS: Lenovo boot default selects the matching server entry safely'
