{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.zenity
    pkgs.python3
    pkgs.playerctl
    (pkgs.writeShellApplication {
      name = "orgm-clipboard-menu";
      runtimeInputs = [ pkgs.glib pkgs.libnotify ];
      text = builtins.readFile ./clipboard-menu.sh;
    })
    (pkgs.writeShellApplication {
      name = "orgm-menu";
      runtimeInputs = [ pkgs.zenity ];
      text = builtins.readFile ./menu.sh;
    })
  ];
}
