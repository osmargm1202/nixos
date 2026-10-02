#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

inventory="$(mktemp)"
trap 'rm -f "$inventory"' EXIT
nix eval --json "path:$ROOT#nixosConfigurations" --apply '
  systems:
  let
    packageNames = packages: map (package: package.pname or package.name) packages;
    describe = system: user:
      let
        config = system.config;
        home = config.home-manager.users.${user};
      in {
        packages = packageNames (config.environment.systemPackages
          ++ config.users.users.${user}.packages ++ home.home.packages);
        flatpaks = config.services.flatpak.packages or [];
        tailscale = config.services.tailscale.enable;
        tailscalePeerMonitorService = builtins.hasAttr "tailscale-peer-monitor" config.systemd.services;
        tailscalePeerMonitorTimer = builtins.hasAttr "tailscale-peer-monitor" config.systemd.timers;
        tailscalePeerNotifierService = builtins.hasAttr "tailscale-peer-notifier" config.systemd.user.services;
        tailscalePeerNotifierTimer = builtins.hasAttr "tailscale-peer-notifier" config.systemd.user.timers;
        secrets = builtins.attrNames (home.sops.secrets or {});
        sourcePaths = map (file: toString file.source)
          (builtins.filter (file: (file.source or null) != null)
            (builtins.attrValues home.home.file));
        mutableUpdater = config.systemd.timers ? orgm-dotfiles-update;
        globalGitIdentity = config.programs.git.config.user or {};
        managedFiles = builtins.attrNames home.home.file;
      };
    jarq = systems.jarq-i3;
    withoutNextcloud = jarq.extendModules {
      modules = [ ({ lib, ... }: {
        orgm.user.programs = lib.mkForce (builtins.filter
          (name: name != "nextcloud") jarq.config.orgm.user.programs);
      }) ];
    };
    withoutTmux = systems.orgm-i3.extendModules {
      modules = [ ({ lib, ... }: {
        orgm.user.programs = lib.mkForce (builtins.filter
          (name: name != "tmux") systems.orgm-i3.config.orgm.user.programs);
      }) ];
    };
    withoutOrgm = systems.orgm-i3.extendModules {
      modules = [ ({ lib, ... }: {
        orgm.user.programs = lib.mkForce (builtins.filter
          (name: name != "orgm") systems.orgm-i3.config.orgm.user.programs);
      }) ];
    };
  in {
    jarq = describe jarq "jarq";
    jarqTerminal = describe systems.jarq-terminal "jarq";
    osmarg = describe systems.orgm-i3 "osmarg";
    withoutNextcloud = describe withoutNextcloud "jarq";
    withoutTmux = describe withoutTmux "osmarg";
    withoutOrgm = describe withoutOrgm "osmarg";
  }
' > "$inventory"

python3 - "$inventory" <<'PY'
import json
import re
import sys

with open(sys.argv[1]) as source:
    inventory = json.load(source)
forbidden = re.compile(r"^(syncthing(?:tray)?|discord(?:-.*)?|steam(?:-.*)?|sunshine|retroarch(?:-.*)?|blender|deskflow|dolphin|orgmai|orgm-bt|orgm-organize|orgm-todo|orgmrnc)$")
for name in ("jarq", "jarqTerminal"):
    configuration = inventory[name]
    leaked = sorted(package for package in configuration["packages"] if forbidden.fullmatch(package))
    assert not leaked, (name, "excluded packages installed", leaked)
    assert configuration["tailscale"], (name, "Tailscale disabled")
    assert not configuration["tailscalePeerMonitorService"], (name, "Tailscale peer monitor service enabled")
    assert not configuration["tailscalePeerMonitorTimer"], (name, "Tailscale peer monitor timer enabled")
    assert not configuration["tailscalePeerNotifierService"], (name, "Tailscale peer notifier service enabled")
    assert not configuration["tailscalePeerNotifierTimer"], (name, "Tailscale peer notifier timer enabled")
    assert not configuration["secrets"], (name, "personal secrets materialized", configuration["secrets"])
    assert not configuration["globalGitIdentity"], (name, "global personal Git identity")
    assert not configuration["mutableUpdater"], (name, "mutable dotfile update timer")
    assert all(source.startswith("/nix/store/") for source in configuration["sourcePaths"]), (name, "mutable dotfile source")

jarq = inventory["jarq"]
flatpaks = {entry if isinstance(entry, str) else entry["appId"] for entry in jarq["flatpaks"]}
required = {"com.anydesk.Anydesk", "io.dbeaver.DBeaverCommunity", "org.sqlitebrowser.sqlitebrowser"}
assert required <= flatpaks, ("missing work applications", required - flatpaks)
excluded = {"com.discordapp.Discord", "org.blender.Blender", "com.moonlight_stream.Moonlight", "io.github.hmlendea.geforcenow-electron"}
assert not excluded & flatpaks, ("excluded Flatpaks installed", excluded & flatpaks)
assert "nextcloud-client" in jarq["packages"], "Nextcloud client missing"
assert "nextcloud-client" not in inventory["withoutNextcloud"]["packages"], "disabling Nextcloud did not remove the client"
assert "syncthing" in inventory["osmarg"]["packages"], "Osmarg lost Syncthing"
assert "syncthingtray" in inventory["osmarg"]["packages"], "Osmarg lost Syncthing Tray"
assert inventory["osmarg"]["secrets"], "Osmarg lost its selected secrets"
assert ".tmux.conf" not in inventory["withoutTmux"]["managedFiles"], "disabled tmux still deploys personal dotfiles"
assert ".config/tmux/plugins.conf" not in inventory["withoutTmux"]["managedFiles"], "disabled tmux still deploys plugins"
for name in ("tailscalePeerMonitorService", "tailscalePeerMonitorTimer", "tailscalePeerNotifierService", "tailscalePeerNotifierTimer"):
    assert inventory["osmarg"][name], ("Osmarg lost Tailscale peer infrastructure", name)
    assert not inventory["withoutOrgm"][name], ("disabling orgm retained Tailscale peer infrastructure", name)
assert inventory["withoutOrgm"]["tailscale"], "disabling orgm disabled Tailscale"
print("PASS: Jarq work applications, exclusions, Tailscale, immutable dotfiles and independent program selection")
PY
