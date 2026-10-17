#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inventory="$(mktemp)"
trap 'rm -f "$inventory"' EXIT
RYOKU_TEST_REPO="$ROOT" nix eval --impure --json --expr '
  let
    f = builtins.getFlake ("path:" + builtins.getEnv "RYOKU_TEST_REPO");
    describe = c: let h = c.home-manager.users.osmarg; in {
      session = builtins.fromJSON h.xdg.configFile."orgm-ryoku/native-session.json".text;
      programs = c.orgm.user.programs;
      packages = map (p: p.pname or (builtins.parseDrvName p.name).name)
        (h.home.packages ++ c.environment.systemPackages);
      masks = map (name: h.xdg.configFile."autostart/${name}".text) [
        "tailscale-systray.desktop" "syncthingtray.desktop" "blueman.desktop"
        "nm-applet.desktop" "print-applet.desktop" "Nextcloud.desktop"
        "com.nextcloud.desktopclient.nextcloud.desktop"
      ];
      tailscale = c.services.tailscale.enable;
      syncthing = builtins.toString (h.systemd.user.services.syncthing.Service.ExecStart or "");
      blueman = c.services.blueman.enable;
      nmApplet = c.programs.nm-applet.enable;
      bluetooth = c.hardware.bluetooth.enable;
      network = c.networking.networkmanager.enable;
      onlineAccounts = c.services.gnome.gnome-online-accounts.enable;
      gvfs = c.services.gvfs.enable;
      printing = c.services.printing.enable;
      automount = builtins.toString c.systemd.user.services.udiskie.serviceConfig.ExecStart;
      helpers = builtins.filter (name: f.inputs.nixpkgs.lib.hasPrefix ".local/bin/hypr-" name)
        (builtins.attrNames h.home.file);
      oldWallpaperInstaller = h.home.activation ? installHyprlandNautilusScript;
    };
    userEmpty = f.nixosConfigurations.envy.extendModules { modules = [
      ({ lib, ... }: { orgm.user.autostart = lib.mkForce []; })
    ]; };
  in {
    hosts = builtins.mapAttrs (_: s: describe s.config)
      { inherit (f.nixosConfigurations) envy lenovo orgm; };
    empty = describe userEmpty.config;
    serverSyncthing = builtins.toString (f.nixosConfigurations.lenovo.config.specialisation.server.configuration
      .home-manager.users.osmarg.systemd.user.services.syncthing.Service.ExecStart or "");
    serverHasSeed = f.nixosConfigurations.lenovo.config.specialisation.server.configuration
      .home-manager.users.osmarg.xdg.configFile ? "orgm-ryoku/native-session.json";
  }
' > "$inventory"
python3 - "$inventory" <<'CHECK'
import json
import sys
x = json.load(open(sys.argv[1]))
for host, c in x["hosts"].items():
    s = c["session"]
    assert s["required"] == [], (host, s)
    assert "tailscale systray --theme light" in s["retired"]
    assert "syncthingtray --single-instance --wait" in s["retired"]
    assert "kdeconnect-indicator" in s["optional"] and "firefox" in s["optional"], host
    assert not any("sunshine" in row for row in s["optional"]), host
    assert all("Hidden=true" in text for text in c["masks"]), host
    assert c["tailscale"] and "syncthing serve --no-browser --no-restart" in c["syncthing"], host
    assert c["bluetooth"] and c["network"] and not c["blueman"] and not c["nmApplet"], host
    assert c["onlineAccounts"] and c["gvfs"] and c["printing"], host
    assert "--automount" in c["automount"] and "--tray" not in c["automount"], host
    assert "syncthingtray" not in c["packages"] and "syncthingtray-minimal" not in c["packages"], host
    assert not c["oldWallpaperInstaller"], host
    assert set(c["helpers"]) == {".local/bin/" + name for name in (
        "hypr-obsidian-open-or-focus", "hypr-pi-prompt", "hypr-rofi-ssh-host",
        "hypr-rofi-lib", "hypr-video-timer")}, (host, c["helpers"])
    nextcloud = host != "envy"
    assert ("nextcloud" in c["programs"]) == nextcloud, host
    assert ("nextcloud-client" in c["packages"]) == nextcloud, host
    assert ("nextcloud --background" in s["optional"]) == nextcloud, host
assert x["empty"]["session"]["optional"] == []
assert x["empty"]["session"]["required"] == []
assert not x["serverHasSeed"]
assert "syncthing serve --no-browser --no-restart" in x["serverSyncthing"]
print("PASS: Ryoku removes duplicate UI, keeps backends/shortcuts, and excludes Nextcloud only on Envy")
CHECK
