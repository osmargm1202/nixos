{
  inputs,
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    inputs.rmatrix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
