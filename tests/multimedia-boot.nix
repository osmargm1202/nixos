# Boots a virtual appliance with the actual greetd/systemd/Sway configuration.
# HDMI, Flatpak downloads and commercial accounts remain hardware acceptance.
{ pkgs, inputs }:
pkgs.testers.runNixOSTest {
  name = "orgm-multimedia-boot";
  node.pkgsReadOnly = false;
  node.specialArgs = {
    inherit inputs;
    userName = "jarq";
    hostName = "jarq";
  };
  nodes.machine = { lib, ... }: {
    imports = [
      ../nixos/users/default.nix
      ../nixos/osk
      ../nixos/tablet.nix
      ../nixos/orgm/default.nix
      ../nixos/profiles/multimedia.nix
    ];
    networking.hostName = "jarq";
    virtualisation.memorySize = 4096;
    virtualisation.cores = 2;
    virtualisation.graphics = true;
    services.journald.extraConfig = "Storage=persistent";
    boot.loader.systemd-boot.enable = lib.mkForce false;
    # Only physical/online integrations are disabled in this offline VM.
    services.fwupd.enable = lib.mkForce false;
    services.thermald.enable = lib.mkForce false;
    powerManagement.powertop.enable = lib.mkForce false;
    services.tailscale.enable = lib.mkForce false;
    systemd.services.orgm-home-flatpaks.enable = lib.mkForce false;
    programs.sway.extraSessionCommands = ''
      export WLR_RENDERER=pixman
    '';
    orgm.multimedia.exposure = "tailscale";
    orgm.multimedia.tailnetAddress = "100.64.0.2";
    orgm.multimedia.lanAddress = "10.0.2.15";
    orgm.multimedia.airplayName = "ORGM Test";
    orgm.multimedia.airplayNetworks = [ "10.0.2.0/24" ];
    systemd.services.test-tailnet = {
      wantedBy = [ "multi-user.target" ];
      before = [ "nginx.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = "${pkgs.iproute2}/bin/ip link add tailscale0 type dummy\n${pkgs.iproute2}/bin/ip addr add 100.64.0.2/32 dev tailscale0\n${pkgs.iproute2}/bin/ip link set tailscale0 up";
    };
    environment.systemPackages = [ pkgs.socat ];
  };
  testScript = ''
    start_all()
    machine.wait_for_unit("orgm-home.service")
    machine.wait_for_unit("greetd.service")
    machine.wait_for_unit("nginx.service")
    machine.wait_for_unit("orgm-home-cast.service")
    machine.wait_until_succeeds("curl --fail http://127.0.0.1:8766/ | grep -F 'ORGM Test'")
    machine.succeed("curl --fail http://127.0.0.1:8766/apps/YouTube | grep -F '<state>stopped</state>'")
    machine.succeed("test $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8766/apps/Netflix) = 404")
    machine.wait_until_succeeds("curl --fail -H 'Host: home.or-gm.com' http://100.64.0.2/api/health", timeout=40)
    machine.succeed("curl --fail -H 'Host: 10.0.2.15' http://127.0.0.1/api/health")
    machine.succeed("test $(curl -s -o /dev/null -w '%{http_code}' -H 'Host: 10.0.2.15' http://127.0.0.1/api/status) = 401")
    machine.wait_until_succeeds("test -S /run/orgm-home/agent.sock", timeout=90)
    query = "echo '{\"action\":\"status\"}' | runuser -u media -- socat -t 30 - UNIX-CONNECT:/run/orgm-home/agent.sock"
    machine.wait_until_succeeds(query + " | jq -e '.ok and .data.session and .data.app == \"home\"'", timeout=120)
    # UxPlay only serves playlists in an active Apple session. Test the exact
    # TCP boundary here without requiring an Apple sender or a fake HTTP page.
    machine.wait_until_succeeds("runuser -u media -- ${pkgs.python3}/bin/python3 -c 'import socket; socket.create_connection((\"127.0.0.1\",7001),3).close()'", timeout=20)
    machine.succeed("runuser -u media -- ${pkgs.python3}/bin/python3 -c 'import socket; socket.create_connection((\"::1\",7001),3).close()'")
    machine.succeed("test $(stat -c %a /var/lib/orgm-home/control-token) = 600")
    machine.succeed("nft list table inet orgm-media-egress")
    machine.succeed("curl --fail http://127.0.0.1:8765/api/health")
    machine.succeed("test $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8765/api/status) = 401")
    machine.succeed("test $(curl -s -o /dev/null -w '%{http_code}' -H 'Host: home.or-gm.com' http://127.0.0.1:8765/api/status) = 401")
    machine.succeed("systemctl restart orgm-home.service")
    machine.wait_for_unit("orgm-home.service")
    machine.wait_until_succeeds(query + " | jq -e '.ok and .data.app == \"home\"'")
    activate_browser = "echo '{\"action\":\"activate\",\"id\":\"browser\"}' | runuser -u media -- socat -t 30 - UNIX-CONNECT:/run/orgm-home/agent.sock"
    machine.succeed(activate_browser + " | jq -e '.ok and .data.app == \"browser\"'")
    browser_pid = machine.succeed("pgrep -o -u media -f -- '--class=orgm-home-browser'").strip()
    machine.succeed("runuser -u media -- env XDG_RUNTIME_DIR=/run/user/1100 systemctl --user restart orgm-home-agent.service")
    machine.wait_until_succeeds(query + " | jq -e '.ok and .data.app == \"browser\"'")
    machine.succeed("kill -0 " + browser_pid)
    machine.succeed("echo '{\"action\":\"home\"}' | runuser -u media -- socat -t 30 - UNIX-CONNECT:/run/orgm-home/agent.sock | jq -e '.ok'")
    airplay = "echo '{\"action\":\"activate\",\"id\":\"airplay\"}' | runuser -u media -- socat -t 30 - UNIX-CONNECT:/run/orgm-home/agent.sock"
    machine.succeed(airplay + " | jq -e '.ok and .data.app == \"airplay\"'")
    machine.succeed("runuser -u media -- env XDG_RUNTIME_DIR=/run/user/1100 systemctl --user is-active orgm-home-airplay")
    machine.wait_until_succeeds("ss -ltn | grep -E ':700[0-2] '")
    machine.wait_until_succeeds("${pkgs.avahi}/bin/avahi-browse -rt _airplay._tcp | grep -F 'ORGM Test'", timeout=30)
    machine.succeed("echo '{\"action\":\"close\"}' | runuser -u media -- socat -t 30 - UNIX-CONNECT:/run/orgm-home/agent.sock | jq -e '.ok and .data.app == \"home\"'")
    machine.fail("runuser -u media -- env XDG_RUNTIME_DIR=/run/user/1100 systemctl --user is-active orgm-home-airplay")
    machine.succeed("runuser -u media -- busctl --system call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanReboot | grep -F yes")
    machine.screenshot("launcher")
    machine.succeed("echo '{\"action\":\"reboot\"}' | runuser -u media -- socat -t 30 - UNIX-CONNECT:/run/orgm-home/agent.sock | jq -e '.ok and .data.accepted'")
    machine.wait_for_shutdown()
    machine.start()
    machine.wait_for_unit("orgm-home.service")
    machine.wait_until_succeeds(query + " | jq -e '.ok and .data.app == \"home\"'", timeout=120)
    machine.succeed("! journalctl -b -1 _SYSTEMD_USER_UNIT=orgm-home-touch.service --no-pager | grep -F 'connection broke'")
  '';
}
