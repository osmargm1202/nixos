{
  userName ? "osmarg",
  ...
}:

let
  localIconsBase = "/home/${userName}/.local/share/icons";
  localIcon = name: "${localIconsBase}/${name}.png";
in
{
  home-manager.users.${userName} = {
    xdg.desktopEntries = {
      vscode-distrobox = {
        name = "VSCode (Arch)";
        genericName = "Text Editor";
        comment = "Visual Studio Code from Arch distrobox";
        exec = "distrobox-enter arch -- code --disable-gpu %F";
        icon = localIcon "vscode";
        categories = [
          "Development"
          "IDE"
        ];
        mimeType = [
          "text/plain"
          "inode/directory"
        ];
        settings = {
          Keywords = "vscode;code;visual studio;distrobox;arch;";
          StartupWMClass = "code";
          StartupNotify = "true";
          NoDisplay = "false";
        };
        terminal = false;
      };

      warp-distrobox = {
        name = "Warp (Arch)";
        genericName = "Terminal";
        comment = "Warp terminal from Arch distrobox";
        exec = "distrobox-enter arch -- warp-terminal";
        icon = localIcon "warp";
        categories = [ "System" "TerminalEmulator" ];
        settings = {
          Keywords = "warp;terminal;distrobox;arch;";
          StartupWMClass = "WarpTerminal";
          StartupNotify = "true";
          NoDisplay = "false";
        };
        terminal = false;
      };
    };
  };
}
