#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
nix eval --impure --raw --expr '
  let
    f = builtins.getFlake ("path:" + toString ./.);
    c = f.nixosConfigurations.jarq-multimedia.config;
    lib = f.inputs.nixpkgs.lib;
  in
  assert c.networking.hostName == "jarq";
  assert c.system.nixos.label == "jarq-multimedia";
  assert c.users.users.jarq.uid == 1000;
  assert c.boot.kernelPackages.kernel.version == "7.0.10";
  assert builtins.elem "iommu=soft" c.boot.kernelParams;
  assert !(builtins.elem "iommu=off" c.boot.kernelParams);
  assert c.orgm.jarq.wifi.experimental.enable;
  assert c.users.users.media.uid == 1100;
  assert c.users.users.media.hashedPassword == "!";
  assert !(builtins.elem "wheel" c.users.users.media.extraGroups);
  assert !(builtins.elem "input" c.users.users.media.extraGroups);
  assert c.services.greetd.enable;
  assert c.services.greetd.settings.initial_session.user == "media";
  assert c.services.greetd.settings.default_session.user == "media";
  assert c.programs.sway.enable;
  assert lib.hasInfix "workspace 99 output HDMI-A-1" c.environment.etc."orgm-home/sway.conf".text;
  assert lib.hasInfix "input type:touch map_to_output eDP-1" c.environment.etc."orgm-home/sway.conf".text;
  assert lib.hasInfix "workspace 7 output eDP-1" c.environment.etc."orgm-home/sway.conf".text;
  assert c.systemd.user.services.orgm-home-touch.environment.ORGM_DISPLAY_SOURCE == "eDP-1";
  assert c.systemd.user.services.orgm-home-display.environment.ORGM_DISPLAY_TARGET == "HDMI-A-1";
  assert c.programs.sway.package.pname == "sway";
  assert !c.services.xserver.enable;
  assert !c.services.displayManager.sddm.enable;
  assert !c.services.desktopManager.plasma6.enable;
  assert !c.services.desktopManager.gnome.enable;
  assert c.orgm.user.programs == [];
  assert !c.orgm.osk.enable;
  assert c.services.logind.settings.Login.HandleLidSwitch == "ignore";
  assert !c.systemd.targets.suspend.enable;
  assert c.services.pipewire.enable && c.services.flatpak.enable;
  assert c.systemd.services.orgm-home.environment.ORGM_BIND == "127.0.0.1";
  assert c.systemd.services.orgm-home.serviceConfig.User == "media";
  assert c.systemd.services.orgm-home.serviceConfig.NoNewPrivileges;
  assert c.systemd.services.orgm-home.serviceConfig.ProtectHome;
  assert c.systemd.user.services.orgm-home-agent.unitConfig.ConditionUser == "media";
  assert builtins.elem "orgm-home-session.target" c.systemd.user.services.orgm-home-kiosk.partOf;
  assert !c.services.cloudflared.enable;
  assert c.services.nginx.enable;
  assert c.orgm.multimedia.exposure == "tailscale";
  assert c.services.nginx.virtualHosts."home.or-gm.com".listen == [{ addr = "100.122.22.48"; port = 80; ssl = false; proxyProtocol = false; extraParameters = []; }];
  assert builtins.elem 80 c.networking.firewall.interfaces.tailscale0.allowedTCPPorts;
  assert builtins.elem 8123 c.networking.firewall.interfaces.tailscale0.allowedTCPPorts;
  assert c.services.home-assistant.enable;
  assert c.services.home-assistant.config.http.server_host == ["127.0.0.1" "::1"];
  assert c.orgm.bomba.localFirst;
  assert !(builtins.elem 8123 c.networking.firewall.allowedTCPPorts);
  assert c.systemd.services.orgm-home.environment.ORGM_REQUIRE_ACCESS == "false";
  assert !(builtins.elem 8765 c.networking.firewall.allowedTCPPorts);
  assert c.networking.nftables.enable;
  assert lib.hasInfix "meta skuid 1100" c.networking.nftables.tables.orgm-media-egress.content;
  assert lib.hasInfix "ct state established,related" c.networking.nftables.tables.orgm-media-egress.content;
  assert lib.hasInfix "127.0.0.1 tcp dport 8765 accept" c.networking.nftables.tables.orgm-media-egress.content;
  assert lib.hasInfix "rocks.shy.VacuumTube" c.systemd.services.orgm-home-flatpaks.script;
  assert lib.hasInfix "com.spotify.Client" c.systemd.services.orgm-home-flatpaks.script;
  assert c.system.build.toplevel.drvPath != "";
  "PASS: evaluated jarq-multimedia session, isolation, recovery and network boundaries\n"
'
