{ ... }:
{
  imports = [ ../sddm-profile-qylock.nix ];

  orgm.sddm = {
    profile = "qylock";
    qylockTheme = "ninja-gaiden";
  };
}
