#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
nix eval --raw --impure --expr '
let
 f = builtins.getFlake ("path:" + toString ./.);
 c = f.nixosConfigurations.envy.config;
 lib = f.inputs.nixpkgs.lib;
 apps = map (p: if builtins.isString p then p else p.appId) c.services.flatpak.packages;
 packages = map (p: lib.getName p) c.environment.systemPackages;
in
assert lib.assertMsg (c.programs.steam.enable && c.programs.gamemode.enable)
 "envy normal must include Steam and GameMode";
assert lib.assertMsg (builtins.all (id: builtins.elem id apps)
 [ "org.libretro.RetroArch" "org.DolphinEmu.dolphin-emu" "net.pcsx2.PCSX2" ])
 "envy must include the shared Lenovo emulators";
assert lib.assertMsg c.services.sunshine.enable "envy must include Sunshine";
assert lib.assertMsg (builtins.elem "nvidia-game" packages)
 "PRIME gaming must supply its NVIDIA-only launcher";
assert lib.assertMsg (!c.orgm.gaming.gamescopeTty1.enable && builtins.attrNames c.specialisation == [ "gaming" "server" "windows-vfio" ] && !c.services.displayManager.autoLogin.enable)
 "adding games must not replace normal with autologin/gaming/Windows";
assert lib.assertMsg (!(c.environment.sessionVariables ? __NV_PRIME_RENDER_OFFLOAD))
 "desktop must not globally force NVIDIA";
"PASS: normal games installed without replacing Intel desktop or normal default\n"
'
launcher=$(nix build --no-link --print-out-paths --impure --expr 'let f = builtins.getFlake ("path:" + toString ./.); in builtins.head (builtins.filter (p: (p.pname or (builtins.parseDrvName p.name).name) == "nvidia-game") f.nixosConfigurations.envy.config.environment.systemPackages)')
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/empty"
printf '#!%s\nprintf "%%s\\0" "$@"\n' "$(command -v bash)" > "$tmp/bin/nvidia-offload"
chmod +x "$tmp/bin/nvidia-offload"
PATH="$tmp/bin" "$launcher/bin/nvidia-game" sample-game "with spaces" --flag > "$tmp/args"
python3 - "$tmp/args" <<"PY"
import pathlib, sys
assert pathlib.Path(sys.argv[1]).read_bytes() == b"sample-game\0with spaces\0--flag\0"
PY
if PATH="$tmp/empty" "$launcher/bin/nvidia-game" sample-game > "$tmp/out" 2> "$tmp/err"; then
  echo "FAIL: launcher silently accepted unavailable PRIME" >&2
  exit 1
fi
[[ ! -s "$tmp/out" ]]
printf "PASS: NVIDIA game launcher forwards exact arguments and refuses Intel fallback\n"
