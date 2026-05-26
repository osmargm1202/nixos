{ lib, buildGoModule }:

buildGoModule {
  pname = "orgm-dot";
  version = "0.1.0";

  src = builtins.path {
    path = ../..;
    name = "orgm-dot-source";
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

  subPackages = [ "cmd/orgm-dot" ];
  vendorHash = null;

  meta = {
    description = "ORGM dotfile manager";
    mainProgram = "orgm-dot";
  };
}
