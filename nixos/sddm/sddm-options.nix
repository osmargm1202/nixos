{
  lib,
  profileName ? null,
  ...
}:
let
  defaultProfile =
    if
      builtins.elem profileName [
        "hyprland"
        "sway"
        "i3"
      ]
    then
      "greenshift"
    else
      "astronaut";
in
{
  options.orgm.sddm = {
    profile = lib.mkOption {
      type = lib.types.enum [
        "greenshift"
        "astronaut"
        "qylock"
      ];
      default = defaultProfile;
      description = "SDDM theme profile.";
    };

    qylockTheme = lib.mkOption {
      type = lib.types.enum [
        "pixel-emerald"
        "enfield"
        "girl-coffee"
        "osu-mania"
        "ninja-gaiden"
        "winter"
        "star-rail"
        "forest"
        "sword"
        "wuthering-waves"
        "clockwork"
        "last-of-us"
        "nier-automata"
        "Genshin"
        "minecraft"
        "material-you-dark"
      ];
      default = "winter";
      description = "Installed Qylock SDDM theme.";
    };
  };
}
