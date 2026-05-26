{ lib, buildGoModule }:

buildGoModule {
  pname = "orgm-hypr";
  version = "0.1.0";

  src = builtins.path {
    path = ../..;
    name = "orgm-hypr-source";
    filter = path: type:
      let
        root = toString ../..;
        rel = lib.removePrefix "${root}/" (toString path);
      in
      rel == "go.mod"
      || rel == "cmd"
      || rel == "internal"
      || lib.hasPrefix "cmd/" rel
      || lib.hasPrefix "internal/" rel;
  };

  subPackages = [ "cmd/orgm-hypr" ];
  vendorHash = null;

  meta = {
    description = "ORGM Hyprland system manager";
    mainProgram = "orgm-hypr";
  };
}
