{
  config,
  lib,
  pkgs,
  userName,
  ...
}:
{
  imports = [ ../../hardware/gpu/intel.nix ];
  # The installer was booted in BIOS mode; GPT's first partition is bios_grub.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/disk/by-id/ata-LITEON_LCH-128V2S_SD0F66155L2TH5910C3B";
    efiSupport = false;
  };
  # Legacy BIOS supplies no BGRT image. Preserve the common firmware-logo
  # theme, adding a small ThinkPad fallback without changing its spinner.
  boot.plymouth = {
    theme = lib.mkForce "thinkpad-bgrt";
    themePackages = [
      (pkgs.callPackage ../../packages/plymouth-thinkpad.nix {
        logo = config.boot.plymouth.logo;
      })
    ];
  };
  boot.initrd.kernelModules = [ "i915" ];
  boot.initrd.verbose = false;
  boot.consoleLogLevel = 0;
  fileSystems."/".options = [ "noatime" ];
  hardware.graphics.extraPackages = [ pkgs.intel-vaapi-driver ];
  services.xserver.videoDrivers = [ "modesetting" ];
  # The 7260 missed beacons and stalled SSH during sustained installation traffic.
  networking.networkmanager.wifi.powersave = false;
  services.thermald.enable = true;
  hardware.bluetooth.powerOnBoot = lib.mkForce false;
  # Credentials are provisioned outside the repository during installation.
  users.users.${userName}.openssh.authorizedKeys.keyFiles = [ ./authorized_keys ];

  # CADCraft 0.13 paints a black window on Bay Trail's hardware OpenGL driver.
  # Verified llvmpipe rendering on this host; keep the workaround app-specific.
  home-manager.users.${userName} = { lib, ... }: {
    home.activation.thinkpadCadcraftGraphics = lib.hm.dag.entryAfter [ "cadcraftFonts" ] ''
      $DRY_RUN_CMD ${pkgs.flatpak}/bin/flatpak override --user \
        --env=WGPU_BACKEND=gl --env=LIBGL_ALWAYS_SOFTWARE=1 \
        --env=LP_NUM_THREADS=2 --env=CADCRAFT_VSYNC=1 \
        --env=WINIT_X11_SCALE_FACTOR=1 ai.storyteller.cadcraft
    '';
  };
}
