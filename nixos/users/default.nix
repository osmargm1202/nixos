# Per-user program selection contract: consumers test
# `builtins.elem "NAME" config.orgm.user.programs`, rather than userName.
# `flatpakPackages` and `webapps` hold the selected IDs for their integrations.
{
  lib,
  userName,
  ...
}:
{
  imports = [
    (./. + "/${userName}.nix")
  ];

  options.orgm.user = {
    programs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Program integrations enabled for the configured user.";
    };

    flatpakPackages = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
      default = [ ];
      description = "Flatpak application IDs or nix-flatpak package definitions enabled for the configured user.";
    };

    webapps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Chromium web application IDs enabled for the configured user.";
    };
  };
}
