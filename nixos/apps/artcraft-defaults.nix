# Standard XDG preference order: missing/unassociated applications are skipped.
{ config, lib, pkgs, userName ? "osmarg", profileName ? null, ... }:
let
  policy = builtins.fromJSON (builtins.readFile ./artcraft-mime-policy.json);
  # xdg.mime serializes lists to strings: mkBefore/mkAfter cannot merge them.
  # Override only this explicit format set, retaining profile-native fallbacks.
  native = mime:
    if builtins.elem mime [ "text/plain" "text/markdown" "text/x-markdown" ] then
      [ (if profileName == "cinnamon" then "xed.desktop" else "org.gnome.TextEditor.desktop") ]
    else if mime == "application/pdf" then
      [ (if profileName == "cinnamon" then "xreader.desktop" else "org.gnome.Evince.desktop") ]
    else if builtins.elem mime [ "image/png" "image/jpeg" "image/webp" "image/gif" "image/svg+xml" ] then
      [ (if profileName == "cinnamon" then "xviewer.desktop" else "org.gnome.Loupe.desktop") ]
    else if profileName == "cinnamon" && builtins.elem mime [ "video/mp4" "video/x-matroska" "video/webm" "video/x-msvideo" ] then
      [ "io.github.celluloid_player.Celluloid.desktop" ]
    else [];
  resolved = lib.mapAttrs (mime: row: lib.unique (row.artcraft ++ native mime ++ row.fallback)) policy;
  manifest = pkgs.writeText "orgm-artcraft-mime-policy.json" (builtins.toJSON resolved);
  updater = pkgs.writeShellScriptBin "orgm-artcraft-defaults" ''
    exec ${pkgs.python3}/bin/python3 ${./artcraft-mime.py} --policy ${manifest} "$@"
  '';
in {
  config = lib.mkIf (profileName != null && profileName != "terminal") {
    xdg.mime.enable = true;
    xdg.mime.defaultApplications = lib.mapAttrs (_: handlers: lib.mkForce handlers) resolved;
    environment.systemPackages = [ updater ];
    home-manager.users.${userName} = { lib, ... }: {
      home.activation.artcraftFileDefaults = lib.hm.dag.entryAfter
        [ "writeBoundary" "setPreferredFileHandlers" "mimeAppsDefaults" ] ''
          $DRY_RUN_CMD ${updater}/bin/orgm-artcraft-defaults
        '';
    };
  };
}
