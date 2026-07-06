# Dotfiles agent instructions

## Deploy mechanism

There is no CLI tool for this anymore (the old `orgm-dot` binary was removed).
Deployment is plain NixOS/home-manager: `nixos/common-dotfiles.nix` (in the
parent `nixos` repo) declares `home.file` entries using
`config.lib.file.mkOutOfStoreSymlink` that point straight at files under this
`dotfiles/` checkout. A path is symlinked from one of:

- `config/shared/<path>` — all hosts
- `config/profiles/<profileName>/<path>` — hosts using that Hyprland/DE profile
- `config/hosts/<hostName>/<path>` — one host only

Priority when a path exists in more than one place: `hostProfilePaths` >
`hostPaths` > `profilePaths` > `sharedPaths` (see `common-dotfiles.nix`).

## Change procedure

1. Edit the tracked source under `config/shared`, `config/profiles/<profile>`,
   or `config/hosts/<host>`. If the path is already in one of the lists below,
   the symlink already points here — **the edit is live immediately**, no
   sync step, no rebuild.
2. If the file/path is new (not yet symlinked anywhere), register it in
   `/home/osmarg/Hobby/nixos/nixos/common-dotfiles.nix` under the matching
   list (`sharedPaths`, a profile's path list, or a host's path list), then
   run `sudo nixos-rebuild switch` on that host to create the symlink.
3. Verify: `readlink -f ~/<path>` should resolve into this dotfiles checkout,
   and the affected app/service should be reloaded (`hyprctl reload`, restart
   the service, etc.) to pick up the change.

## Scope notes

- NixOS system configuration and Go system executables live in `/home/osmarg/Hobby/nixos`.
- This dotfiles repo owns user configuration, icons, desktop files, and small scripts.
- `config/shared` is for files shared by all hosts.
- `config/hosts/orgm` and other host directories are for host-specific files.
- `config/dotfiles.json`'s `local_only.paths`/`local_defaults.paths` are still read
  by `common-dotfiles.nix` as documented exclusions (local secrets/state that must
  never be symlinked). Its `shared`/`hosts` sections are legacy and no longer
  consumed by anything — the real path lists live in `common-dotfiles.nix` itself.
- For desktop launchers, prefer storing them under `config/shared/.local/share/applications` unless they are host-specific.
