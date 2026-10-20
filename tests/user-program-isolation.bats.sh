#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

inventory="$(mktemp)"
trap 'rm -f "$inventory"' EXIT
nix eval --impure --json "path:$ROOT#nixosConfigurations" --apply '
  systems:
  let
    historical = import ./tests/fixtures/legacy-configurations.nix;
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
        peerNotifications = config.orgm.tailscale.peerNotifications.enable;
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
    jarq = systems.jarq;
    withoutNextcloud = jarq.extendModules {
      modules = [ ({ lib, ... }: {
        orgm.user.programs = lib.mkForce (builtins.filter
          (name: name != "nextcloud") jarq.config.orgm.user.programs);
      }) ];
    };
    withoutTmux = systems.orgm.extendModules {
      modules = [ ({ lib, ... }: {
        orgm.user.programs = lib.mkForce (builtins.filter
          (name: name != "tmux") systems.orgm.config.orgm.user.programs);
      }) ];
    };
    withoutOrgm = systems.orgm.extendModules {
      modules = [ ({ lib, ... }: {
        orgm.user.programs = lib.mkForce (builtins.filter
          (name: name != "orgm") systems.orgm.config.orgm.user.programs);
      }) ];
    };
    withPeerNotifications = systems.orgm.extendModules {
      modules = [ ({ lib, ... }: { orgm.tailscale.peerNotifications.enable = lib.mkForce true; }) ];
    };
    withoutPeerNotifications = jarq.extendModules {
      modules = [ ({ lib, ... }: { orgm.tailscale.peerNotifications.enable = lib.mkForce false; }) ];
    };
    withoutSyncthing = jarq.extendModules {
      modules = [ ({ lib, ... }: {
        orgm.user.programs = lib.mkForce (builtins.filter
          (name: name != "syncthing") jarq.config.orgm.user.programs);
      }) ];
    };
    terminalWithoutSyncthing = historical.jarq-terminal.extendModules {
      modules = [ ({ lib, ... }: {
        orgm.user.programs = lib.mkForce (builtins.filter
          (name: name != "syncthing") historical.jarq-terminal.config.orgm.user.programs);
      }) ];
    };
  in {
    jarq = describe jarq "jarq";
    jarqTerminal = describe historical.jarq-terminal "jarq";
    osmarg = describe systems.orgm "osmarg";
    withoutNextcloud = describe withoutNextcloud "jarq";
    withoutTmux = describe withoutTmux "osmarg";
    withoutOrgm = describe withoutOrgm "osmarg";
    withPeerNotifications = describe withPeerNotifications "osmarg";
    withoutPeerNotifications = describe withoutPeerNotifications "jarq";
    withoutSyncthing = describe withoutSyncthing "jarq";
    terminalWithoutSyncthing = describe terminalWithoutSyncthing "jarq";
    osmargRyoku = describe systems.orgm-ryoku "osmarg";
  }
' > "$inventory"

python3 - "$inventory" <<'PY'
import json
import re
import sys

with open(sys.argv[1]) as source:
    inventory = json.load(source)
forbidden = re.compile(r"^(discord(?:-.*)?|steam(?:-.*)?|sunshine|retroarch(?:-.*)?|blender|deskflow|dolphin)$")
orgm_commands = {'orgmai', 'orgm-bt', 'orgm-organize', 'orgm-todo', 'orgmrnc'}
for name in ("jarq", "jarqTerminal"):
    configuration = inventory[name]
    leaked = sorted(package for package in configuration["packages"] if forbidden.fullmatch(package))
    assert not leaked, (name, "excluded packages installed", leaked)
    assert 'syncthing' in configuration['packages'], (name, 'selected Syncthing missing')
    assert orgm_commands <= set(configuration['packages']), (name, 'selected ORGM tools missing')
    assert configuration["tailscale"], (name, "Tailscale disabled")
    assert configuration['peerNotifications'], (name, 'selected ORGM peer notification default missing')
    for component in ('tailscalePeerMonitorService', 'tailscalePeerMonitorTimer',
                      'tailscalePeerNotifierService', 'tailscalePeerNotifierTimer'):
        assert configuration[component], (name, 'selected peer infrastructure missing', component)
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
for name in ('withoutSyncthing', 'terminalWithoutSyncthing'):
    assert not {'syncthing', 'syncthingtray'} & set(inventory[name]['packages']), (name, 'disabled Syncthing leaked')
assert not orgm_commands & set(inventory['withoutOrgm']['packages']), 'disabled ORGM tools leaked'
assert 'syncthingtray' not in inventory['jarqTerminal']['packages'], 'terminal installed a GUI sync tray'
for name in ('osmarg', 'osmargRyoku'):
    assert 'syncthingtray' not in inventory[name]['packages'], (name, 'duplicate Syncthing tray')
assert inventory["osmarg"]["secrets"], "Osmarg lost its selected secrets"
assert ".tmux.conf" not in inventory["withoutTmux"]["managedFiles"], "disabled tmux still deploys personal dotfiles"
assert ".config/tmux/plugins.conf" not in inventory["withoutTmux"]["managedFiles"], "disabled tmux still deploys plugins"
for name in ("tailscalePeerMonitorService", "tailscalePeerMonitorTimer", "tailscalePeerNotifierService", "tailscalePeerNotifierTimer"):
    assert not inventory["osmarg"][name], ("Osmarg retained disabled Tailscale peer infrastructure", name)
    assert inventory["withPeerNotifications"][name], ("explicit peer notifications missing infrastructure", name)
    assert not inventory["withoutOrgm"][name], ("disabling orgm retained Tailscale peer infrastructure", name)
    assert not inventory['withoutPeerNotifications'][name], ('explicitly disabled peer notifications retained infrastructure', name)
assert inventory["withoutOrgm"]["tailscale"], "disabling orgm disabled Tailscale"
assert inventory['withoutPeerNotifications']['tailscale'], 'disabling peer notifications disabled Tailscale'
print("PASS: Jarq work applications, exclusions, Tailscale, editable dotfile copies and independent program selection")
PY
