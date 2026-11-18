{
  config,
  lib,
  pkgs,
  userName ? "osmarg",
  ...
}:
let
  enabled = builtins.elem "flatpak" config.orgm.user.programs;
  discordEnabled = builtins.elem "discord" config.orgm.user.programs;
  # Shared desktop baseline, independent of the user's personal app list.
  # ArtCraft publishes bundles, not a Flathub application. The pinned bundle is
  # only the first-install seed: the launcher updates itself and its apps, so
  # Nix must not own it (nix-flatpak would put the pinned version back).
  artcraftId = "ai.storyteller.artcraft-launcher";
  artcraftVersion = config.orgm.artcraft.launcher.version;
  artcraftSha256 = config.orgm.artcraft.launcher.sha256;
  artcraftBundle = pkgs.fetchurl {
    url = "https://github.com/storytold/craft-launcher/releases/download/v${artcraftVersion}/artcraft-launcher-${artcraftVersion}-linux-x86_64.flatpak";
    sha256 = artcraftSha256;
  };
  packages =
    config.orgm.user.flatpakPackages
    ++ lib.optional config.orgm.flatpak.remmina.enable "org.remmina.Remmina";
  # Install the launcher for the user only when no installation has it. A user
  # install lets "Update and restart" replace it without a polkit prompt.
  artcraftBootstrap = pkgs.writeShellScript "orgm-artcraft-launcher-bootstrap" ''
    flatpak=${pkgs.flatpak}/bin/flatpak
    if $flatpak info --user ${artcraftId} >/dev/null 2>&1 \
      || $flatpak info --system ${artcraftId} >/dev/null 2>&1; then
      exit 0
    fi
    exec $flatpak install --user --noninteractive --assumeyes ${artcraftBundle}
  '';
  discord = pkgs.callPackage ./discord-webrtc.nix { };
  windowsFontNames = pkgs.callPackage ../packages/windows-font-names.nix {
    microsoftOfficeFonts = pkgs.callPackage ../packages/microsoft-office-fonts.nix { };
  };
in
{
  options.orgm.artcraft.launcher = {
    version = lib.mkOption {
      type = lib.types.str;
      default = "0.19.2";
      description = "Launcher bundle installed when it is missing; later updates are the launcher's own.";
    };
    sha256 = lib.mkOption {
      type = lib.types.str;
      default = "238825b7ad3f1b16374428357d2acc7c97c7dbc5d36b1d53123d604a969969bd";
    };
  };
  options.orgm.flatpak.remmina.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Include the shared Remmina client in the desktop baseline.";
  };
  config = lib.mkIf enabled {
    environment.systemPackages = [
      (import ./x11-client-pid.nix { inherit pkgs; })
    ]
    ++ lib.optional discordEnabled discord;

    services.fwupd.enable = true;
    services.flatpak = {
      enable = packages != [ ];
      remotes = [
        {
          name = "flathub";
          location = "https://flathub.org/repo/flathub.flatpakrepo";
        }
      ];
      overrides = { };
      inherit packages;
    };

    # Retire only the replaced client, including copies not recorded in the
    # nix-flatpak state. Other manually installed applications remain managed
    # by their existing owner.
    systemd.services.flatpak-managed-install.postStart = ''
      if ${pkgs.flatpak}/bin/flatpak info --system com.spotify.Client >/dev/null 2>&1 \
        && ${pkgs.flatpak}/bin/flatpak info --system rocks.fastpotify.Fastpotify >/dev/null 2>&1; then
        ${pkgs.flatpak}/bin/flatpak uninstall --system --noninteractive --assumeyes rocks.fastpotify.Fastpotify
      fi
    '';

    home-manager.users.${userName} = { lib, ... }: {
      config = lib.mkMerge [
        {
          # Keep the upstream Flatpak and its updates. Install a reusable-window
          # desktop entry only when CADCraft exists; TryExec preserves native
          # fallback when the Flatpak is removed. Do not touch other app defaults.
          home.activation.cadcraftOpening = lib.hm.dag.entryAfter [ "orgmDotBootstrap" "writeBoundary" ] ''
            if [ -x "$HOME/.local/bin/orgm-cadcraft" ]; then
              $DRY_RUN_CMD ${pkgs.coreutils}/bin/env PATH=${
                lib.makeBinPath [
                  pkgs.python3
                  pkgs.flatpak
                  pkgs.desktop-file-utils
                ]
              }:"$PATH" \
                ${pkgs.bash}/bin/bash "$HOME/.local/bin/orgm-cadcraft" install
            fi
          '';
          # CADCraft (user flatpak, outside nix-flatpak) ignores fontconfig and the
          # host fonts in /run/host/fonts: it only scans ~/.local/share/fonts, by
          # Windows file name, and follows at most one symlink, so copy real files.
          home.activation.cadcraftFonts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            fonts="$HOME/.local/share/fonts/windows-names"
            $DRY_RUN_CMD rm -rf "$fonts"
            $DRY_RUN_CMD mkdir -p "$fonts"
            $DRY_RUN_CMD cp -L --no-preserve=mode ${windowsFontNames}/share/fonts/windows-names/* "$fonts"/
            if ${pkgs.flatpak}/bin/flatpak info --user ai.storyteller.cadcraft >/dev/null 2>&1 \
              || ${pkgs.flatpak}/bin/flatpak info --system ai.storyteller.cadcraft >/dev/null 2>&1; then
              $DRY_RUN_CMD ${pkgs.flatpak}/bin/flatpak override --user --filesystem=xdg-data/fonts:ro ai.storyteller.cadcraft
            fi
          '';
          home.activation.removeFastpotify = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            if ${pkgs.flatpak}/bin/flatpak info --user rocks.fastpotify.Fastpotify >/dev/null 2>&1; then
              $DRY_RUN_CMD ${pkgs.flatpak}/bin/flatpak uninstall --user --noninteractive --assumeyes rocks.fastpotify.Fastpotify
            fi
          '';
        }
        (lib.mkIf discordEnabled {
          xdg.desktopEntries."com.discordapp.Discord" = {
            name = "Discord";
            genericName = "Internet Messenger";
            comment = "All-in-one voice and text chat";
            exec = "${discord}/bin/discord %U";
            icon = "com.discordapp.Discord";
            terminal = false;
            type = "Application";
            categories = [
              "Network"
              "InstantMessaging"
            ];
            mimeType = [ "x-scheme-handler/discord" ];
            settings = {
              StartupWMClass = "discord";
              X-Flatpak = "com.discordapp.Discord";
            };
          };
        })
      ];
    };

    systemd.user.services.orgm-artcraft-launcher-bootstrap = {
      description = "Install ArtCraft Launcher once; it updates itself afterwards";
      wantedBy = [ "default.target" ];
      unitConfig = {
        StartLimitIntervalSec = 3600;
        StartLimitBurst = 10;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = artcraftBootstrap;
        # The first login may come before the network that fetches the runtime.
        Restart = "on-failure";
        RestartSec = 120;
      };
    };

    # A fresh machine installs the bundles after the first HM activation.
    # Finish their user integration once both the dotfiles and apps exist.
    systemd.services.orgm-artcraft-integrations = {
      description = "Register ArtCraft file opening and CADCraft fonts";
      wantedBy = [ "graphical.target" ];
      after = [
        "flatpak-managed-install.service"
        "home-manager-${userName}.service"
      ];
      requires = [ "home-manager-${userName}.service" ];
      path = with pkgs; [
        bash
        python3
        flatpak
        desktop-file-utils
        coreutils
      ];
      environment.HOME = "/home/${userName}";
      serviceConfig = {
        Type = "oneshot";
        User = userName;
      };
      script = ''
        if flatpak info --user ai.storyteller.cadcraft >/dev/null 2>&1 \
          || flatpak info --system ai.storyteller.cadcraft >/dev/null 2>&1; then
          flatpak override --user --filesystem=xdg-data/fonts:ro ai.storyteller.cadcraft
          if [ -x "$HOME/.local/bin/orgm-cadcraft" ]; then
            "$HOME/.local/bin/orgm-cadcraft" install
          fi
        fi
        /run/current-system/sw/bin/orgm-artcraft-defaults
      '';
    };
  };
}
