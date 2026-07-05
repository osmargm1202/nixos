# wayland-vpets (bongocat) overlay — https://github.com/furudbat/wayland-vpets
# Run `bongocat-find-devices` and set `programs.wayland-bongocat.inputDevices`
# per host to react to keypresses; without it the overlay just sits idle.
{ inputs, ... }:
{
  imports = [ inputs.wayland-vpets.nixosModules.default ];

  programs.wayland-bongocat = {
    enable = true;
    autostart = true;
  };
}
