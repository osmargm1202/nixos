# Engram packaging pending

Current Home Manager module: `nixos/home/engram.nix`.

Why not packaged now:
- Current install uses `go install github.com/Gentleman-Programming/engram/cmd/engram@latest` during activation.
- A declarative Nix package should pin an upstream revision/version and include trusted `src` hash plus `vendorHash`.
- This session was explicitly no-build/no-network/no-eval, so no hash was generated or invented.

Suggested next step when builds/network are allowed:
1. Add `nixos/packages/engram.nix` using `buildGoModule`.
2. Pin upstream revision/tag for `github.com/Gentleman-Programming/engram`.
3. Fill `hash` and `vendorHash` from a trusted Nix build/update flow.
4. Replace activation install in `nixos/home/engram.nix` with `home.packages = [ pkgs.go engram ];` or equivalent flake package wiring.
5. Remove activation-time `go install @latest` after package works.
