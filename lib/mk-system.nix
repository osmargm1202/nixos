{
  inputs,
  nixpkgs,
  system,
  defaultHardware,
  profiles,
}:

let
  inherit (nixpkgs) lib;

  getProfile =
    profileName:
    profiles.${profileName}
      or (throw "Unknown ORGMOS profile '${profileName}'. Valid profiles: ${builtins.concatStringsSep ", " (builtins.attrNames profiles)}");

  mkSystem =
    {
      hostName,
      role,
      hardware ? defaultHardware,
      profile ? null,
      profileName ? null,
      extraModules ? [ ],
      userName ? "osmarg",
    }:
    let
      effectiveProfileName =
        if profileName != null then
          profileName
        else if role == "terminal" then
          "terminal"
        else
          null;
      roleModules =
        if role == "desktop" then
          [
            ../nixos/common.nix
            ../nixos/ai/default.nix
            hardware
            (if profile != null then profile else throw "Desktop role requires a profile module")
            { networking.hostName = hostName; }
          ]
        else if role == "server" then
          [
            ../nixos/ai/default.nix
            hardware
            ../nixos/server.nix
            { networking.hostName = hostName; }
          ]
        else if role == "terminal" then
          [
            ../nixos/ai/default.nix
            hardware
            ../nixos/terminal.nix
            { networking.hostName = hostName; }
          ]
        else
          throw "Unknown ORGMOS role '${role}'. Valid roles: desktop, server, terminal";
    in
    lib.nixosSystem {
      specialArgs = {
        inherit inputs userName;
      }
      // lib.optionalAttrs (effectiveProfileName != null) {
        profileName = effectiveProfileName;
      };
      modules = [
        { nixpkgs.hostPlatform = system; }
        ../nixos/binary-cache.nix
      ]
      ++ roleModules
      ++ extraModules;
    };

  mkHost =
    args:
    mkSystem (
      args
      // {
        role = "desktop";
      }
    );

  mkProfile =
    args:
    mkSystem (
      args
      // {
        role = "desktop";
        hardware = defaultHardware;
        hostName = args.hostName or "nixos";
      }
    );

  mkGeneralHost =
    {
      hardware,
      profile,
      hostName,
      extraModules ? [ ],
      userName ? "osmarg",
    }:
    mkSystem {
      role = "desktop";
      inherit
        hardware
        hostName
        extraModules
        userName
        ;
      profile = getProfile profile;
      profileName = profile;
    };

  mkServerHost =
    args:
    mkSystem (
      args
      // {
        role = "server";
      }
    );

  mkMinimalHost =
    args:
    mkSystem (
      args
      // {
        role = "terminal";
      }
    );

  mkTerminalHost = mkMinimalHost;
in
{
  inherit
    mkSystem
    mkHost
    mkProfile
    mkGeneralHost
    mkServerHost
    mkMinimalHost
    mkTerminalHost
    ;
}
