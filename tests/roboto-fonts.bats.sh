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

# Matching must work from the package alone, not an unrelated user/system copy.
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

font_package="$(nix build --impure --no-link --print-out-paths --expr '
  (builtins.getFlake ("path:" + toString ./.)).nixosConfigurations.orgm.pkgs.roboto
')"
cat > "$tmp/fonts.conf" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <dir>$font_package/share/fonts/truetype</dir>
  <cachedir>$tmp/cache</cachedir>
</fontconfig>
EOF

for family in Roboto RobotoCondensed; do
  expected_family="$family"
  faces=(Regular Italic Medium MediumItalic Bold BoldItalic)
  if [[ "$family" == RobotoCondensed ]]; then
    expected_family="Roboto Condensed"
    faces+=(Light LightItalic)
  fi
  for face in "${faces[@]}"; do
    expected="$face"
    case "$face" in
      MediumItalic) expected="Medium Italic" ;;
      BoldItalic) expected="Bold Italic" ;;
      LightItalic) expected="Light Italic" ;;
    esac
    file="$font_package/share/fonts/truetype/$family-$face.ttf"
    actual="$(fc-scan --format '%{family[0]}|%{style[0]}' "$file")"
    [[ "$actual" == "$expected_family|$expected" ]] || {
      printf 'FAIL metadata: %s-%s: %s\n' "$family" "$face" "$actual" >&2
      exit 1
    }
    matched="$(FONTCONFIG_FILE="$tmp/fonts.conf" fc-match \
      -f '%{family[0]}|%{style[0]}|%{file}' "$expected_family:style=$expected")"
    [[ "$matched" == "$expected_family|$expected|$file" ]] || {
      printf 'FAIL matching: %s-%s: %s\n' "$family" "$face" "$matched" >&2
      exit 1
    }
  done
done
printf 'PASS: Roboto6 and Roboto Condensed8 real faces and isolated Fontconfig matching\n'
