{
  lib,
  buildGoModule,
  dotfilesOrgmSource,
}:

let
  filteredSource = builtins.path {
    path = dotfilesOrgmSource;
    name = "dotfiles-orgm";
    filter =
      path: type:
      let
        root = toString dotfilesOrgmSource;
        rel = lib.removePrefix "${root}/" (toString path);
      in
      rel == "go.mod"
      || rel == "cmd"
      || rel == "internal"
      || lib.hasPrefix "cmd/" rel
      || lib.hasPrefix "internal/" rel;
  };
in
buildGoModule {
  pname = "orgm-dot";
  version = "0.1.0";

  src = filteredSource;

  subPackages = [ "cmd/orgm-dot" ];
  vendorHash = null;

  meta = {
    description = "ORGM dotfiles manager";
    mainProgram = "orgm-dot";
  };
}
