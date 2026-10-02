{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (builtins.elem "deskflow" config.orgm.user.programs) {
    # Install Deskflow as a regular application. Users launch it explicitly.
    services.flatpak.packages = lib.mkAfter [ "org.deskflow.deskflow" ];
  };
}
