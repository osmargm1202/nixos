{ lib, ... }:

{
  # Install Deskflow as a regular application. Users launch it explicitly when needed.
  services.flatpak.packages = lib.mkAfter [ "org.deskflow.deskflow" ];
}
