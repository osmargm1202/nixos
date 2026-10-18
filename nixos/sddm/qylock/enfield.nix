{ ... }:
{
  imports = [ ../sddm-profile-qylock.nix ];

  orgm.sddm = {
    profile = "qylock";
    qylockTheme = "enfield";
  };
}
