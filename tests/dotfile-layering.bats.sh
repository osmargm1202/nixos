#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" <<'PY'
import fnmatch
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])
base = root / "dotfiles/config"
metadata = {".git", ".gitignore", ".DS_Store", "icon-theme.cache", "mimeinfo.cache"}

def collect(layer):
    source = base / layer
    result = {}
    if not source.exists():
        return result
    def walk(directory, prefix=""):
        for entry in os.scandir(directory):
            name = entry.name
            if name in metadata or any(fnmatch.fnmatchcase(name, pat) for pat in ("Icon?", "*~", "*.bak")):
                continue
            target = prefix + name
            if entry.is_symlink() or entry.is_file(follow_symlinks=False):
                assert Path(entry.path).exists(), f"Missing source: {entry.path}"
                result[target] = f"config/{layer}/{target}"
            elif entry.is_dir(follow_symlinks=False):
                walk(entry.path, target + "/")
    walk(source)
    return result

for host in (base / "hosts").iterdir():
    assert not any((host / legacy).exists() for legacy in (".config", ".local", ".pi")), f"Legacy host layout: {host}"
    assert all(entry.name in ("shared", "profiles") for entry in host.iterdir()), f"Unexpected host layer: {host}"

shared = collect("shared")
hypr = collect("profiles/hyprland")
persistent = {target: source for target, source in hypr.items() if target.startswith((
    ".config/hypr/", ".config/orgm-hypr/", ".config/waybar-hypr/", ".local/bin/hypr-", ".local/bin/waybar-"
))}
for name in ("hypr-menu.rasi", "hypr-menu.env", "orgm-current.rasi"):
    source = f"config/profiles/hyprland/.config/rofi/{name}"
    assert (root / "dotfiles" / source).exists(), f"Missing Rofi remap: {source}"
    persistent[f".config/orgm-hypr/rofi/{name}"] = source

for output, host, profile in (("orgm-hyprland", "orgm", "hyprland"), ("lenovo-hyprland", "lenovo", "hyprland"), ("orgm-i3", "orgm", "i3"), ("hyprland", "", "hyprland")):
    expected = shared | persistent | collect(f"profiles/{profile}")
    if host:
        expected |= collect(f"hosts/{host}/shared")
        expected |= collect(f"hosts/{host}/profiles/{profile}")
    expected.pop(".local/share/nautilus/scripts/Set as Hyprland Wallpaper", None)
    # Compare evaluated sources against links to the independently composed
    # runtime paths. This checks the winning source, not just target presence.
    expected_json = json.dumps(json.dumps(expected))
    expression = '''hm: let
      expected = builtins.fromJSON EXPECTED;
      runtime = hm.home.homeDirectory + "/Hobby/nixos/dotfiles/";
    in {
      targets = builtins.attrNames hm.home.file;
      migration = hm.home.activation.migrateLegacyDotfileDirectories.data;
      cleanup = hm.home.activation.removeConflictingDotfiles.data;
      sourcesMatch = builtins.mapAttrs (target: relative:
        builtins.hasAttr target hm.home.file &&
        toString hm.home.file.${target}.source ==
          toString (hm.lib.file.mkOutOfStoreSymlink (runtime + relative))
      ) expected;
    }'''.replace("EXPECTED", expected_json)
    result = subprocess.run(["nix", "eval", "--json", f"path:{root}#nixosConfigurations.{output}.config.home-manager.users.osmarg", "--apply", expression], text=True, capture_output=True, check=True)
    evaluated = json.loads(result.stdout)
    wrong = [target for target, matches in evaluated["sourcesMatch"].items() if not matches]
    assert not wrong, f"{output}: wrong or missing sources: {wrong}"
    targets = set(evaluated["targets"])
    assert ".bashrc" in targets and ".local/bin/hypr-wallpaper" in targets, output
    assert expected[".bashrc"] == "config/shared/.bashrc", output
    if host:
        assert f".config/bash/host-{host}.bash" in targets, output
    if profile == "hyprland" and host:
        assert f".config/hypr/lua/monitors/{host}.lua" in targets, output
    if output == "orgm-hyprland":
        assert expected[".config/orgm-hypr/display-targets.json"].startswith("config/hosts/orgm/profiles/hyprland/"), output
        assert expected[".config/rofi/hypr-menu.env"].startswith("config/hosts/orgm/profiles/hyprland/"), output
        # Exercise evaluated migration arguments in a disposable HOME. Both an
        # old whole-directory link and a nested icons link must be detached.
        command = shlex.split(evaluated["migration"].replace("\\\n", ""))
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            (home / ".config/bash").mkdir(parents=True)
            for target in (".config/btop", ".config/bash/icons"):
                (home / target).symlink_to(f"/nix/store/test-home-manager-files/{target}")
            marker = home / ".config/bash/user-local.bash"
            marker.write_text("preserve\n")
            skill = home / ".pi/agent/skills/find-skills"
            external = home / ".agents/skills/find-skills"
            skill.parent.mkdir(parents=True)
            external.mkdir(parents=True)
            (external / "SKILL.md").write_text("external original\n")
            (external / "local-notes.txt").write_text("preserve notes\n")
            skill.symlink_to("../../../.agents/skills/find-skills")
            subprocess.run([str(root / "nixos/scripts/migrate-home-manager-dotfile-dirs.sh"), *command[2:]], env=os.environ | {"HOME": str(home)}, check=True)
            assert all((home / target).is_dir() and not (home / target).is_symlink() for target in (".config/btop", ".config/bash/icons"))
            assert marker.read_text() == "preserve\n"
            subprocess.run(["bash", "-euc", evaluated["cleanup"]], env=os.environ | {"HOME": str(home), "DRY_RUN_CMD": ""}, check=True)
            assert not skill.is_symlink() and skill.is_dir()
            assert (external / "SKILL.md").read_text() == "external original\n"
            assert (skill / "local-notes.txt").read_text() == "preserve notes\n"
            assert not (skill / "SKILL.md").exists(), "Cleanup must remove only the independent managed copy"
            backups = list(skill.parent.glob("find-skills.hm-migration.*.original-link"))
            assert len(backups) == 1 and backups[0].resolve() == external
    if output == "lenovo-hyprland":
        assert ".config/hypr/lua/monitors/orgm.lua" not in targets, output
    if profile == "i3":
        assert ".config/i3/config" in targets, output
        assert ".config/hypr/lua/monitors/orgm.lua" not in targets, output
        assert not any("hosts/orgm/profiles/hyprland/" in source for source in expected.values()), output
        assert expected[".config/rofi/hypr-menu.env"].startswith("config/profiles/i3/"), output
        assert expected[".config/dunst/dunstrc"].startswith("config/profiles/i3/"), output
    if not host:
        assert not any(target.startswith(".config/bash/host-") or target in (".config/hypr/lua/monitors/orgm.lua", ".config/hypr/lua/monitors/lenovo.lua") for target in targets), output
    print(f"PASS: {output}: {len(expected)} source files, precedence and source integrity")
print("PASS: dotfile layering")
PY
