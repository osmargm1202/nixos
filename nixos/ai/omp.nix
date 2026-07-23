# Oh My Pi (OMP) — install via `bun install -g @oh-my-pi/pi-coding-agent`.
# Bun places `omp` in ~/.bun/bin, already added to PATH by Fish; update with `omp update`.
# This module does not install OMP itself; it provides the supported native runtime.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    bun
  ];
}
