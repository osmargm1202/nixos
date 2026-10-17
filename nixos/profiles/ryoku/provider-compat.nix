# Keep temporary provider fixes at the locked package boundary, not in Hub data.
{ inputs, pkgs, lib }:
let
  upstream = inputs.ryoku;
  system = pkgs.stdenv.hostPlatform.system;
  original = upstream.packages.${system};
  hyprland = original.ryoku-wm-hyprland.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace ryoku/wm/hyprland/act.go \
        --replace-fail 'hl.dsp.dpms({ state = ' 'hl.dsp.dpms({ action = '
    '';
  });
  niri = original.ryoku-wm-niri.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace ryoku/wm/niri/config_rules.go \
        --replace-fail 'kdlNum(parseFloat(r.Value, 0.5))' 'kdlFloat(parseFloat(r.Value, 0.5))'
    '';
  });
  desktopData = original.ryoku-desktop-data.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      install -Dm644 ${upstream.outPath}/ryoku/apps/bash/ryoku.bash "$out/share/ryoku/config/bash/ryoku.bash"
      install -Dm644 ${upstream.outPath}/ryoku/apps/bash/rashin.bash "$out/share/ryoku/config/bash/rashin.bash"
      install -Dm644 ${upstream.outPath}/ryoku/apps/terminal-shell/env.sh "$out/share/ryoku/config/ryoku-terminal/env.sh"
    '';
  });
  cli = original.ryoku-cli.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      install -m0644 ${./materialize-directory-guard.go} internal/updater/materialize_directory_guard.go
      substituteInPlace internal/updater/materialize.go \
        --replace-fail '// ~/.config/ryoku is where' 'if err := guardMaterializeDirectories(base, dest, state); err != nil { return err }
        // ~/.config/ryoku is where'
      gofmt -w internal/updater/materialize_directory_guard.go internal/updater/materialize.go
      substituteInPlace internal/updater/materialize.go \
        --replace-fail 'return generatedSeed[rel] || strings.HasPrefix(rel, "nvim/")' \
          'return generatedSeed[rel] || rel == "starship.toml" || strings.HasPrefix(rel, "btop/") || strings.HasPrefix(rel, "nvim/")'
      substituteInPlace internal/sys/useredits.go \
        --replace-fail 'if strings.HasPrefix(rel, "nvim/") {' \
          'if rel == "starship.toml" || strings.HasPrefix(rel, "btop/") || strings.HasPrefix(rel, "nvim/") {'
    '';
    installPhase = builtins.replaceStrings
      [ (toString original.ryoku-desktop-data) ] [ (toString desktopData) ] old.installPhase;
  });
  replacements = [
    { before = original.ryoku-wm-hyprland; after = hyprland; }
    { before = original.ryoku-wm-niri; after = niri; }
    { before = original.ryoku-desktop-data; after = desktopData; }
    { before = original.ryoku-cli; after = cli; }
  ];
  replacePackage = p: lib.foldl' (result: replacement:
    if toString p == toString replacement.before then replacement.after else result
  ) p replacements;
  materializer = original.ryoku-materialize.overrideAttrs (old:
    assert builtins.all (r: lib.hasInfix
      (builtins.unsafeDiscardStringContext (toString r.before)) old.text) replacements;
    {
      text = builtins.replaceStrings
        (map (r: toString r.before) replacements)
        (map (r: toString r.after) replacements) old.text;
    });
  bundle = original.ryoku-bundle.overrideAttrs (old: {
    paths = map replacePackage old.paths;
  });
  packages = original // {
    ryoku-desktop-data = desktopData;
    ryoku-cli = cli;
    ryoku-wm-hyprland = hyprland;
    ryoku-wm-niri = niri;
    ryoku-materialize = materializer;
    ryoku-bundle = bundle;
  };
  # Reuse the upstream module factory and its exact pinned package set/overlays.
  # Only self.packages changes, including the materializer's absolute provider
  # reference. The module's session PATH and live wrapper therefore agree with HM.
  fixedSelf = upstream // {
    packages = upstream.packages // { ${system} = packages; };
  };
  outputs = (import (upstream.outPath + "/flake.nix")).outputs
    (upstream.inputs // { self = fixedSelf; });
in {
  inherit packages;
  module = outputs.nixosModules.default;
}
