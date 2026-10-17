# Keep temporary provider fixes at the locked package boundary, not in Hub data.
{ inputs, pkgs, lib }:
let
  upstream = inputs.ryoku;
  system = pkgs.stdenv.hostPlatform.system;
  original = upstream.packages.${system};
  compositor = original.ryoku-hyprland;
  buildDeps = lib.unique (lib.concatMap (p: [ p ] ++ (p.propagatedBuildInputs or []))
    ([ compositor ] ++ compositor.buildInputs));
  pluginTools = [ pkgs.git pkgs.gnumake pkgs.cmake pkgs.pkg-config
    compositor.stdenv.cc pkgs.binutils pkgs.coreutils ];
  hyprland = original.ryoku-wm-hyprland.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ./animation-preset-provider.patch ];
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.makeWrapper ];
    postInstall = (old.postInstall or "") + ''
      wrapProgram "$out/bin/ryoku-wm-hyprland" \
        --prefix PATH : ${lib.makeBinPath pluginTools} \
        --prefix PKG_CONFIG_PATH : ${lib.makeSearchPathOutput "dev" "lib/pkgconfig" buildDeps}:${lib.makeSearchPathOutput "dev" "share/pkgconfig" buildDeps}
    '';
    postPatch = (old.postPatch or "") + ''
      substituteInPlace ryoku/wm/hyprland/config_plugins.go \
        --replace-fail '/usr/lib/hyprland/plugins' '${original.ryoku-hypr-plugins}/lib/hyprland/plugins'
      substituteInPlace ryoku/wm/hyprland/config_plugins_tier.go \
        --replace-fail 'return filepath.Join(p, "hyprland", "src", "version.h")' 'return "${lib.getDev compositor}/include/hyprland/src/version.h"'
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
  hub = original.ryoku-hub.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ./animation-preset-hub.patch ];
  });
  desktopData = original.ryoku-desktop-data.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ./sleep-button.patch ./animation-preset-ui.patch ];
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
    { before = original.ryoku-hub; after = hub; }
  ];
  replacePackage = p: lib.foldl' (result: replacement:
    if toString p == toString replacement.before then replacement.after else result
  ) p replacements;
  materializer = original.ryoku-materialize.overrideAttrs (old:
    assert builtins.all (r: lib.hasInfix
      (builtins.unsafeDiscardStringContext (toString r.before)) old.text) (lib.filter (r: toString r.before != toString original.ryoku-hub) replacements);
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
    ryoku-hub = hub;
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
