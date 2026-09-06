{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "orgm-themes";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../..;
    fileset = lib.fileset.unions [
      ../../go.mod
      ../../cmd/orgm-themes
      ../../internal/cli
      ../../internal/orgmtheme
      ../../dotfiles/config/profiles/hyprland/.config/orgm-theme/themes
    ];
  };

  subPackages = [ "cmd/orgm-themes" ];
  vendorHash = null;
  doCheck = true;

  meta.mainProgram = "orgm-themes";
}
