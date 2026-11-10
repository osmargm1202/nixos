# Use the maintained nixpkgs package without moving the system's package set.
{
  inputs,
  system ? "x86_64-linux",
}:
(import inputs.nixpkgs-browser {
  inherit system;
  config.allowUnfree = true;
}).brave-origin
