#!/usr/bin/env python3
"""Check the installed profile contract, including absence of unwanted runtimes."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
projection = r'''s: let c=s.config; in {
  host=c.networking.hostName;
  user=c.users.users.hm.name;
  context=builtins.fromJSON c.environment.etc."orgm-dot/context.json".text;
  light=c.orgm.i3.lightweight;
  osk=c.orgm.osk.enable;
  picom=builtins.hasAttr "picom" c.systemd.user.services;
  chromium=c.orgm.chromium.enable;
  steam=c.programs.steam.enable;
  gamescope=c.programs.steam.gamescopeSession.enable;
  sddm=c.services.displayManager.sddm.enable;
  lightdm=c.services.xserver.displayManager.lightdm.enable;
  efi=c.boot.loader.systemd-boot.enable;
  grub=c.boot.loader.grub.enable;
  emulators=c.orgm.gaming.emulators;
  zram=c.zramSwap.enable;
  maxJobs=c.nix.settings.max-jobs;
  ai=c.home-manager.users.hm.xdg.configFile."i3/config.d/60-ai.conf".text;
  browser=c.xdg.mime.defaultApplications."text/html";
  browserBridge=c.home-manager.users.hm.programs.firefox.package.outPath == c.programs.firefox.finalPackage.outPath;
  editor=c.xdg.mime.defaultApplications."text/x-python";
  rootSsh=c.services.openssh.settings.PermitRootLogin;
  artcraftTargets=c.systemd.services.orgm-artcraft-integrations.wantedBy;
  flatpakAfter=c.systemd.services.flatpak-managed-install.after;
  webapps=c.orgm.user.webapps;
  flatpaks=map (p: if builtins.isString p then p else p.appId) c.services.flatpak.packages;
  clipboard=c.home-manager.users.hm.xresources.properties."XTerm*selectToClipboard";
  terminal=c.home-manager.users.hm.xresources.properties."orgm.i3.terminal";
  status=c.home-manager.users.hm.xresources.properties."orgm.i3.statusCommand";
  barFont=c.home-manager.users.hm.xresources.properties."orgm.i3.barFont";
  monitorGuard=c.systemd.services.autorandr.unitConfig.ConditionPathExistsGlob;
  plymouth=c.boot.plymouth.enable;
  bootTheme=c.boot.plymouth.theme;
  earlyGpu=c.boot.initrd.kernelModules;
  prebuiltEditor=c.orgm.neovim.prebuilt;
  packages=map (p: p.pname or (s.pkgs.lib.getName p)) c.environment.systemPackages;
}'''
c = json.loads(subprocess.check_output([
    "nix", "eval", "--impure", "--json", f"path:{root}#nixosConfigurations.thinkpad11e", "--apply", projection
], text=True))
assert (c["host"], c["user"], c["context"]["profile"]) == ("thinkpad11e", "hm", "i3")
assert all(c[key] for key in ("light", "steam", "lightdm", "grub", "zram", "chromium"))
assert not any(c[key] for key in ("osk", "picom", "gamescope", "sddm", "efi"))
assert c["emulators"] == {"tier": "classic", "backend": "native"}
assert c["maxJobs"] == 0
assert c["rootSsh"] == "no"
assert not set(c["artcraftTargets"]) & set(c["flatpakAfter"]), "ArtCraft creates a boot ordering cycle"
assert c["monitorGuard"] == "/run/user/1000/i3/ipc-socket.*"
assert c["browser"] == "chromium-browser.desktop"
assert c["browserBridge"]
assert c["editor"] == "nvim.desktop"
assert all(command in c["ai"] for command in ("orgmai new", "orgmai prev", "orgmai config", "i3-pi-prompt"))
assert "i3-lightweight" in c["context"]["programs"]
print("PASS: thinkpad11e hardware, isolated hm preferences, lightweight i3, AI, Firefox and classic gaming")

assert set(c["webapps"]) == {"fast", "netflix", "disney-plus", "hbo-max", "kick", "youtube", "youtube-kids", "poki", "crunchyroll", "chatgpt", "claude", "twitch"}
assert {"com.spotify.Client", "io.github.flattool.Warehouse", "com.github.tchx84.Flatseal"} <= set(c["flatpaks"])
assert c["terminal"] == "xterm" and c["status"] == "exec env I3_STATUS_PICOM=0 ~/.local/bin/i3status-localized"
assert c["barFont"] == "JetBrainsMono Nerd Font 9.5"

assert c["clipboard"] is True
assert c["plymouth"] and c["bootTheme"] == "thinkpad-bgrt"
assert "i915" in c["earlyGpu"]
assert c["prebuiltEditor"] and "neovim" in c["context"]["programs"]
assert {"neovim", "galculator", "xfce4-taskmanager", "gnome-disk-utility", "gucharmap", "mousepad"} <= set(c["packages"])
