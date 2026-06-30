# Dotfiles agent instructions

## orgm-dot workflow

Use the installed host `orgm-dot` to compare and apply managed dotfiles.

Preferred commands use the fast subcommand form, without `--` on the command.
Do not pass `--host` for normal `orgm` work: the current `orgm-dot` resolves the host from the environment/host context.
When running from this distrobox/container, call the host binary through `distrobox-host-exec` because `orgm-dot` may not be installed in the container PATH.

```bash
distrobox-host-exec orgm-dot status
distrobox-host-exec orgm-dot diff
distrobox-host-exec orgm-dot sync
distrobox-host-exec orgm-dot daemon
distrobox-host-exec orgm-dot add ~/.config/example --shared
distrobox-host-exec orgm-dot remove ~/.config/example --shared
```

Host-specific add/remove is only needed for non-shared paths. Prefer the current host-aware form documented by `orgm-dot help`; avoid stale examples with `--host orgm` unless explicitly testing older repo code.

Legacy command flags like `--diff` and `--sync` may still work, but do not use them in new notes or examples.

## Change procedure

1. Edit the tracked source under `config/shared` or `config/hosts/<host>`.
2. If the file is new, add the path to `config/dotfiles.json` under `shared.paths` or `hosts.<host>.paths`.
3. Check what will change:

   ```bash
   distrobox-host-exec orgm-dot diff
   ```

4. Apply the configuration to the destination home:

   ```bash
   distrobox-host-exec orgm-dot sync
   ```

5. Verify the application or config that changed.

## Scope notes

- NixOS system configuration and Go system executables live in `/home/osmarg/Hobby/nixos`.
- This dotfiles repo owns user configuration, icons, desktop files, and small scripts.
- `config/shared` is for files shared by all hosts.
- `config/hosts/orgm` and other host directories are for host-specific files.
- `local_only.paths` in `config/dotfiles.json` protects local secrets/state from being synced.
- For desktop launchers, prefer storing them under `config/shared/.local/share/applications` unless they are host-specific.
