# Tailscale + Fleet SSH Picker Design

**Date:** 2026-07-09
**Repo:** osmargm1202/nixos

---

## Problem

Remote support for machines behind NAT the user doesn't control (e.g. `jarq`'s
machine) currently requires asking for the current IP every time — fragile,
manual, and doesn't work at all if the remote router has no port forwarding.
There's also no way to see at a glance which of the fleet (`orgm`, `lenovo`,
`ero`, `jarq`) are currently online or when they were last seen.

---

## Solution Overview

1. **Tailscale** on every machine gives each one a stable identity reachable
   from anywhere, regardless of the underlying network/NAT, plus built-in
   online/offline + last-seen tracking (`tailscale status --json`). This
   replaces the originally-proposed custom systemd IP-reporting service —
   Tailscale already solves that problem.
2. A small **host registry file** (`hosts.conf`) maps each tailnet hostname to
   its SSH login user (usernames differ per machine — `jarq` uses `jarq`,
   the rest use `osmarg`). Synced via the existing dotfiles pipeline so every
   machine has the same up-to-date list.
3. A **fish function** (`sshgo`) cross-references the registry against live
   Tailscale status, shows a `gum` picker with online/offline + last-seen per
   host, and `exec ssh`s into whichever one is selected — using Tailscale
   MagicDNS hostnames, so no IPs are ever stored or typed.

Auth to the tailnet is manual per machine (`sudo tailscale up
--auth-key=tskey-auth-... --accept-dns`, key generated from the Tailscale
admin console) — not stored in the flake or sops, run once per host after
rebuild.

---

## Architecture

### New / modified files

```
nixos/
├── tailscale.nix                              [NEW]
├── common.nix                                 [MODIFIED — import tailscale.nix]
├── server.nix                                  [MODIFIED — import tailscale.nix]
├── terminal.nix                                [MODIFIED — import tailscale.nix]
└── common-dotfiles.nix                        [MODIFIED — sync .config/orgm-hosts]

dotfiles/config/shared/
├── .config/orgm-hosts/hosts.conf              [NEW — host->user registry]
└── .config/fish/functions/sshgo.fish          [NEW]
```

### `nixos/tailscale.nix`

```nix
{ ... }:
{
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "client";
}
```

Imported by `common.nix`, `server.nix`, `terminal.nix` — all three profiles
get Tailscale, matching the "todas" scope decision. No secrets involved;
`tailscale up` is run manually per machine post-rebuild.

### `hosts.conf`

Plain two-column text, one host per line, no TOML/YAML dependency:

```
orgm osmarg
lenovo osmarg
ero osmarg
jarq jarq
```

Lives at `dotfiles/config/shared/.config/orgm-hosts/hosts.conf`, added to
`sharedPaths` in `common-dotfiles.nix` (same symlink mechanism as every other
shared dotfile) so it's available on every machine after a dotfiles sync,
without needing a rebuild to update.

### `sshgo` fish function

**Dependencies:** `jq` and `gum` on all three profiles. `gum` is already in
`common.nix` but missing from `server.nix`/`terminal.nix`; `jq` is already in
`terminal.nix`/`server.nix` but missing from `common.nix`. Add the missing
package to each so `sshgo` works on every profile.

1. Read `~/.config/orgm-hosts/hosts.conf` into `(hostname, user)` pairs.
2. Run `tailscale status --json` once; parse with `jq` for each peer's
   `HostName`, `Online`, `LastSeen`.
3. Cross-reference by hostname (case-insensitive match), building display
   rows:
   ```
   orgm     osmarg   🟢 online
   lenovo   osmarg   🔴 offline (last seen 2026-07-08T14:20:00Z)
   ```
4. Feed rows to `gum choose`. This view **is** the "see who's online / last
   seen" requirement — no separate list-only function needed. `Ctrl+C`
   cancels without connecting.
5. On selection, parse the chosen row's hostname + user and
   `exec ssh $user@$hostname` (MagicDNS resolves the name — no IP ever
   touches this function).

Deliberately simple, left for later if actually needed:
- "Last seen" shown as a raw ISO timestamp, not a humanized "3h ago" —
  avoids adding a relative-time dependency for a nice-to-have.
- No pre-flight reachability check before `ssh` — if a host is offline the
  `ssh` attempt just times out normally; no need to block selection on it.

---

## Error Handling

- `hosts.conf` missing or empty → `sshgo` prints a clear message and exits;
  no crash.
- `tailscale status --json` failing (tailscale not running / not logged in
  on the local machine) → surface the raw error from `tailscale`, exit
  non-zero, no attempt to fake a peer list.
- A host in `hosts.conf` with no matching Tailscale peer (typo, or that
  machine never ran `tailscale up`) → shown in the picker as `❓ unknown`
  rather than silently dropped, so registry/tailnet drift is visible.

---

## Testing

- Manual: run `sshgo` with at least one peer online and one offline/unknown,
  confirm the picker shows correct status per row and `ssh` fires with the
  right user for both a `osmarg`-user host and the `jarq`-user host.
- `nix flake check` after the `tailscale.nix` module + import changes, across
  all three profiles (common/server/terminal), same as every other change in
  this repo.
