#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

nix eval --impure --raw --expr '
  let
    f = builtins.getFlake ("path:" + toString ./.);
    lib = f.inputs.nixpkgs.lib;
    systems = f.nixosConfigurations // {
      font-test-server = f.lib.mkServerHost { hostName = "font-test-server"; };
      font-test-terminal = f.lib.mkTerminalHost { hostName = "font-test-terminal"; };
    };
    check = name: c:
      assert lib.assertMsg (c.fonts.fontconfig.enable
        && builtins.any (p: lib.getName p == "roboto") c.fonts.packages)
        "${name}: full Roboto (not just RobotoMono Nerd Font) must be installed";
      assert lib.assertMsg (c.fonts.fontconfig.defaultFonts.sansSerif == [ "DejaVu Sans" ])
        "${name}: installing Roboto must not change the default sans-serif font";
      true;
    checkSystem = name: s:
      check name s.config
      && lib.all (mode: check "${name}/${mode}" s.config.specialisation.${mode}.configuration)
        (builtins.attrNames s.config.specialisation);
  in assert lib.all (name: checkSystem name systems.${name}) (builtins.attrNames systems);
  "PASS: full Roboto in every host, role and boot mode without changing defaults\n"
'

font_package="$(nix build --impure --no-link --print-out-paths --expr '
  (builtins.getFlake ("path:" + toString ./.)).nixosConfigurations.orgm.pkgs.roboto
')"
for face in Regular Italic Medium MediumItalic Bold BoldItalic; do
  expected="$face"
  case "$face" in
    MediumItalic) expected="Medium Italic" ;;
    BoldItalic) expected="Bold Italic" ;;
  esac
  actual="$(fc-scan --format '%{family[0]}|%{style[0]}' \
    "$font_package/share/fonts/truetype/Roboto-$face.ttf")"
  [[ "$actual" == "Roboto|$expected" ]] || {
    printf 'FAIL: %s: %s\n' "$face" "$actual" >&2
    exit 1
  }
done
printf 'PASS: real Regular/Italic/Medium/MediumItalic/Bold/BoldItalic font faces\n'
