{ lib, fetchFromGitHub, hyprland, mkHyprlandPlugin, lua5_4 }:
# Upstream hyprpm.toml pins this revision to Hyprland v0.55.4 / a0136d8c.
# Do not carry the plugin forward silently when the compositor ABI changes.
assert lib.assertMsg (hyprland.version == "0.55.4")
  "ScrollOverview's pinned revision requires Hyprland 0.55.4; update the upstream compatibility pin first.";
mkHyprlandPlugin {
  pluginName = "hyprland-scroll-overview";
  version = "cfc23b194ba9378d1606c7aa73060f6ffbe38445";
  inherit hyprland;
  src = fetchFromGitHub {
    owner = "yayuuu";
    repo = "hyprland-scroll-overview";
    rev = "cfc23b194ba9378d1606c7aa73060f6ffbe38445";
    hash = "sha256-hjzhIWCmaqVtyCy2ZE1+pM3Q2BvAGuC8zQZSj1AtORA=";
  };
  buildInputs = [ lua5_4 ];
  dontConfigure = true;
  enableParallelBuilding = true;
  buildPhase = ''
    runHook preBuild
    make all
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 scrolloverview.so "$out/lib/libscrolloverview.so"
    runHook postInstall
  '';
  passthru.hyprlandForPlugin = hyprland;
  meta = {
    description = "Niri-style workspace overview for Hyprland";
    homepage = "https://github.com/yayuuu/hyprland-scroll-overview";
    license = lib.licenses.bsd3;
  };
}
