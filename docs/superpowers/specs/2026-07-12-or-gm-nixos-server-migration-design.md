# OR-GM Arch Linux to NixOS Server Migration Design

**Date:** 2026-07-12  
**Status:** Approved design; implementation intentionally deferred  
**Target host:** `or-gm`  
**Future repository:** `/home/osmarg/Code/nixos-server`

## 1. Goal

Migrate `or-gm` from Arch Linux to a reproducible, headless NixOS server without Docker, Docker Compose, containerd, CasaOS, or imperative production services.

The migration must:

- preserve approved persistent data;
- archive selected retired projects;
- discard explicitly rejected services and data after verification;
- keep the 2.7 TiB data disk intact;
- deploy native NixOS modules where available;
- deploy custom application stacks through flakes owned by their source repositories;
- keep Cloudflared as the primary HTTP ingress;
- keep Tailscale for private administration;
- support direct public ports only where protocol or upload limits require them;
- restore every approved service automatically after reboot;
- keep the desktop NixOS repository independent from server deployments.

No migration, repository creation, data copy, service stop, or NixOS installation is part of this design phase.

## 2. Current Host Findings

### 2.1 Hardware and storage

- Hardware: HP EliteDesk 800 G3 TWR.
- Current OS: Arch Linux.
- Current kernel observed: Linux 7.0.12.
- `sda`, 238.5 GiB:
  - EFI system partition at `/boot`;
  - ext4 root filesystem at `/`.
- `sdb`, 2.7 TiB:
  - one ext4 filesystem;
  - mounted at `/home`;
  - also used through special mounts for some Docker volume paths.
- zram swap is active.

### 2.2 Host services observed

Active or enabled services include:

- OpenSSH;
- Tailscale;
- fail2ban;
- UFW;
- systemd-networkd;
- Samba/NMB;
- rclone;
- CUPS;
- Avahi;
- CasaOS services;
- Docker/containerd;
- devmon/udevil;
- local getty.

### 2.3 Main risks

- Persistent application data is split between `/home`, `/DATA`, and `/var/lib/docker/volumes`.
- Several databases remain inside Docker named volumes on the root disk.
- Some paths under `/var/lib/docker/volumes` are special mounts backed by the large disk, which obscures physical data location.
- Many containers publish ports on all IPv4 and IPv6 interfaces.
- The current firewall and effective sshd configuration require root access for a complete audit.
- Many images use floating tags such as `latest` or `main`.
- A root-disk reinstall would destroy Docker volumes still located on `sda`.

## 3. Architectural Boundaries

## 3.1 `nixos-server` responsibility

The future `/home/osmarg/Code/nixos-server` repository is the single source of truth for host composition. It owns:

- the `or-gm` NixOS configuration;
- hardware and disk mounts;
- users and groups;
- networking and firewall policy;
- OpenSSH, Tailscale, and Cloudflared;
- sops-nix integration;
- backup policy;
- Caddy or nginx integration;
- activation of approved native services;
- pinned inputs for custom stack flakes;
- host-level checks and runbooks.

Proposed layout:

```text
nixos-server/
├── flake.nix
├── flake.lock
├── hosts/or-gm/
│   ├── default.nix
│   ├── hardware-configuration.nix
│   ├── disks.nix
│   └── services.nix
├── modules/
│   ├── core/
│   ├── networking/
│   ├── storage/
│   ├── backups/
│   └── services/
├── secrets/
├── migrations/
├── tests/
└── docs/runbooks/
```

`hosts/or-gm/services.nix` activates only approved services. If an application must survive reboot, it must be reachable from this host configuration through a native module or imported flake module.

## 3.2 Application repository responsibility

Each existing Docker Compose application stack that will survive must eventually own a flake in its existing source repository. This work starts only after the base NixOS server is installed.

A stack repository should export:

```text
packages.<system>.default
nixosModules.default
checks.<system>.*
```

Its module owns the application's internal topology, including its dedicated database, cache, object storage, workers, initialization, migrations, service ordering, and health checks.

`nixos-server` owns only host integration:

- enabling the imported module;
- pinning its revision in `flake.lock`;
- assigning external data paths;
- supplying sops-nix secret paths;
- selecting ingress policy;
- selecting backup policy.

Databases that are part of a product stack remain inside that stack's module. They are not forced into a shared global database.

## 3.3 Native service responsibility

Services with validated NixOS modules use those modules directly. Small local wrappers may normalize data paths, secrets, backup metadata, users/groups, and exposure policy, but must not duplicate upstream module implementation.

## 4. Persistent Data Design

## 4.1 Canonical paths

Persistent application state will live under:

```text
/home/osmarg/services/<service>/
├── data/<component>/
├── config/
├── secrets/
└── backups/
```

Application source remains separate, normally under `/home/osmarg/Code`.

No production application stores mutable state inside a Git checkout or the Nix store.

## 4.2 Disk installation policy

- Reinstall and format only `sda`.
- Preserve `sdb` without formatting.
- Continue mounting `sdb` at `/home` by UUID.
- Record and manually verify the UUID before installation.
- Ensure the installer cannot automatically repartition `sdb`.
- Prefer leaving `sdb` unmounted during `sda` partitioning, then mounting it explicitly.
- Do not install NixOS until every required root-disk volume has been moved or archived and tested.

## 4.3 Volume migration tool

The migration tool must be manifest-driven and process one service per execution. It must never discover and move arbitrary volumes automatically.

Each manifest entry records:

- source volume or bind path;
- target path under `/home/osmarg/services`;
- owning stack and containers;
- data type and database version;
- whether data is durable or regenerable;
- pre-copy backup command;
- stop and start commands;
- ownership and permission requirements;
- verification command;
- health check;
- rollback procedure.

Per-service migration sequence:

1. Validate free space, source, target, ownership, and stack identity.
2. Produce logical database dumps where applicable.
3. Stop the complete owning stack during the approved nighttime maintenance window.
4. Copy data while preserving ownership, modes, ACLs, xattrs, hard links, and timestamps where relevant.
5. Verify file counts, checksums, and database dumps.
6. Change the temporary Compose configuration from named volumes to explicit bind mounts.
7. Start only that stack.
8. Run functional and health checks.
9. Roll back to the original volume if validation fails.
10. Preserve the original volume until the NixOS deployment and restoration are accepted.

There is no strict downtime limit during the nighttime window. Consistency and recovery take priority over speed.

## 4.4 Data to exclude

Do not migrate regenerable state unless later evidence changes classification:

- caches;
- build outputs;
- `node_modules`;
- Strapi build/cache volumes;
- downloaded machine-learning model caches;
- container layers;
- Docker overlay data;
- logs without an explicit retention requirement;
- unidentified orphan volumes approved for deletion.

## 5. Backup and Secret Design

## 5.1 Pre-install backup

The approved temporary pre-install copy exists only on `sdb`. This is not a full external backup and does not protect against failure of the data disk.

Mandatory compensating controls:

- separate backup directories from active service paths;
- checksums for archives;
- logical database dumps;
- restoration tests;
- copies of required Arch `/etc` configuration, Compose files, service definitions, credentials, and keys;
- verified NixOS installer disk plan;
- no formatting or repartitioning of `sdb`.

## 5.2 Permanent backup

After migration:

- critical databases and application state receive a local backup and encrypted Restic backup to a VPS;
- database-aware dumps run before filesystem backup;
- Vaultwarden, ORGM databases/object stores, DNS data, Paperless documents, Immich database, Open WebUI user data, registry auth, and infrastructure secrets are critical unless later reclassified;
- multimedia remains local only;
- model caches and other regenerable data are excluded;
- retention policies differ by data class;
- restoration tests run periodically.

## 5.3 Secrets

Use sops-nix with age.

Encrypted secrets may be committed. Private age identities must never enter Git. Secrets are materialized under `/run/secrets` with the minimum required owner, group, and permissions.

Covered secret types include:

- Cloudflare tunnel tokens;
- database credentials;
- MinIO/S3 credentials;
- SMTP credentials;
- ORGM application secrets;
- Restic/VPS credentials;
- API keys;
- registry authentication;
- rclone configuration credentials.

## 6. Network and Recovery Design

## 6.1 Exposure classes

Every approved service has exactly one primary exposure class:

- `cloudflared`: default for HTTP applications;
- `tailscale-only`: administration and private tools;
- `direct-public`: explicit exception for protocol or upload constraints;
- `local-only`: bound to loopback or LAN only.

Rules:

- firewall closed by default;
- databases, Redis, MinIO, and internal workers never exposed publicly;
- qBittorrent P2P requires a direct port, while its UI remains private;
- Jellyfin and Immich may need direct ingress because of media upload/streaming limits;
- DNS ports are direct only when the service's role requires them;
- proxy configuration is declarative Caddy/nginx, not Nginx Proxy Manager;
- Homepage never accesses the Docker socket.

## 6.2 Recovery access

Initial recovery uses physical console/getty, OpenSSH, and Tailscale.

PiKVM is an approved future improvement, not a migration blocker. It will be external to `nixos-server`. Future documentation should cover DisplayPort-to-HDMI capture, USB keyboard emulation, optional ATX control, network isolation, and recovery testing.

## 7. Approved Native NixOS Services

The following module availability was validated against the pinned nixpkgs used during research. Exact options and versions must be revalidated when the future repository pins its own nixpkgs revision.

### 7.1 New required services

- Sonarr;
- Radarr;
- Prowlarr;
- Bazarr;
- Paperless-ngx;
- MicroBin.

### 7.2 Existing services to retain natively

- Homepage;
- Immich;
- Jellyfin with Intel hardware acceleration if validated on the EliteDesk;
- Open WebUI, using remote providers and no local Ollama;
- Pi-hole;
- pyLoad;
- qBittorrent;
- OCI registry;
- standalone Redis, after identifying its consumers;
- Uptime Kuma;
- Vaultwarden;
- Cloudflared;
- Tailscale;
- Samba/SFTP;
- rclone;
- OpenSSH;
- fail2ban;
- NixOS firewall;
- Caddy or nginx;
- Restic;
- sops-nix.

### 7.3 Native service notes

#### Homepage

Homepage becomes the single dashboard. It must:

- list only approved current services;
- use declarative configuration rather than Docker discovery;
- have no Docker socket access;
- use simple, modern, responsive, accessible custom CSS;
- avoid exposing secrets to the browser.

The visual redesign is a later, separate subproject.

#### Immich

- Migrate library and database.
- Regenerate machine-learning cache.
- Validate the current specialized PostgreSQL extensions and version before import.
- Determine whether direct ingress is required for large uploads.

#### Jellyfin

- Migrate configuration and metadata.
- Preserve media on `sdb`.
- Validate Intel VA-API support.
- Test direct play and hardware transcoding.

#### Open WebUI

- Normalize its current special-mounted volume to the canonical path.
- Preserve users and chats as critical data.
- Do not migrate Ollama models.
- Configure remote model/API providers.

#### Pi-hole and ORGM DNS

Both are retained. Their roles and ports must not conflict. A later service design must define whether clients query Pi-hole first and which resolver or authoritative role ORGM DNS performs.

#### qBittorrent, pyLoad, and media services

Use a dedicated shared group and explicit media/download paths. Do not solve access with world-writable permissions.

#### Registry OCI

Retain the actual active registry data and authentication. Do not retain the orphan Prometheus metrics volume. Configure garbage collection and upload-compatible ingress.

#### Standalone Redis

Identify all consumers before migration. Do not use it as an implicit shared dependency for stacks that need dedicated versions or policies.

#### Vaultwarden

Treat all state, attachments, keys, and configuration as critical. A successful restoration test is a hard gate before reinstalling the root disk.

#### rclone

Identify remote, mount/sync mode, and consumers. Store credentials via sops-nix and encode service ordering for dependent applications.

## 8. Approved Custom Stack Flakes

These stacks migrate later, after the base NixOS host is operational. Each receives a flake in its own existing source repository or dedicated stack repository.

### 8.1 Análisis EDES

- Package application reproducibly.
- Export NixOS module and checks.
- Define data, secrets, domain, and health endpoint.

### 8.2 Dagendang

One stack module owns:

- web application;
- Strapi;
- PostgreSQL;
- Redis;
- MinIO;
- initialization and migrations.

Migrate database, object data, uploads, and required configuration. Do not migrate Strapi cache, build, or `node_modules` volumes.

### 8.3 MSG ORGM

- Package in its own repository.
- Define state, secrets, domain, and health checks.

### 8.4 ORGM Admin

One stack module owns:

- backend;
- PostgreSQL 17 or the validated compatible version;
- MinIO;
- idempotent MinIO initialization;
- migrations and health checks.

Database and object storage are critical.

### 8.5 ORGM Landing Page

`orgm_nextjs` and `orgm-lp` are the same logical service. `ORGM LP` is the canonical future name.

- Keep one deployment only.
- Adapt the source repository for reproducible build and deployment.
- Prefer stateless operation unless later evidence finds persistent state.

### 8.6 ORGM Seguimiento

One stack module owns application, PostgreSQL, MinIO, migrations, initialization, and checks. Database and objects are critical.

### 8.7 ORGM DNS

- Package in its own repository.
- Preserve zones/configuration and secrets as critical data.
- Define authoritative or recursive role before opening direct DNS ports.
- Test resolution and rollback of zone changes.

### 8.8 ORGM Server

- Package in its own repository.
- Normalize persistent state.
- Do not classify ordinary logs as critical unless required.

### 8.9 ROMM

One stack module owns:

- ROMM;
- MariaDB;
- Redis;
- library;
- assets, resources, and configuration.

Inspect and identify the anonymous `/romm` volume before migration.

### 8.10 WebODM / Drone Map

One stack module owns:

- WebODM web application;
- workers;
- NodeODM;
- PostgreSQL;
- Redis broker;
- media;
- existing project scripts.

`webodm_appmedia` and `webodm_dbdata` are critical. Broker data is presumed regenerable but must be validated.

## 9. Retired and Replaced Services

## 9.1 Discard after verification

The following do not migrate and do not receive future flakes:

- 2FAuth;
- Adminer;
- Appsmith;
- Dashy;
- Healthchecks and its PostgreSQL database;
- InsForge and its components;
- LibreChat/RAG, MongoDB, Meilisearch, pgvector, and uploads;
- Radisson Paneles;
- standalone PostgREST;
- Portainer and `portainer_data`;
- Watchtower;
- docker socket proxy;
- CasaOS;
- CUPS and Epson driver;
- Avahi/mDNS;
- Ollama and local models;
- devmon/udevil.

Deletion always follows a minimal identity check. No volume is deleted merely because its name appears on this list.

## 9.2 Archive, then retire

### Authentik

- Do not deploy on NixOS.
- Export `authentik_database` if recoverable.
- Verify archive before removal.

### n8n

- Do not deploy on NixOS.
- Archive PostgreSQL dump, `n8n_data`, workflows, encrypted credentials, encryption key, and sanitized Compose configuration.
- Verify restoration, then retire.

## 9.3 Replacements

- File Browser → Samba/SFTP with explicit roots and permissions.
- Nginx Proxy Manager → declarative Caddy/nginx and Cloudflared routes.
- Docker/Compose/containerd → native NixOS modules and custom stack flakes.
- Healthchecks does not migrate; Uptime Kuma remains the primary monitor.

## 10. Orphan Volume Findings

Research found 36 Docker volumes with no associated container:

- 28 anonymous hash-named volumes;
- 8 named volumes.

Named volume decisions:

| Volume | Decision |
|---|---|
| `authentik_database` | Export/archive, then retire |
| `docker-registry_prometheus-data` | Inspect; discard if only historical metrics |
| `n8n_data` | Archive with n8n, then retire |
| `nginx-data` | Preserve as legacy archive |
| `nginx-letsencrypt` | Preserve as legacy archive |
| `orgm_img` | Verify identity, then discard |
| `orgm_portada` | Verify identity, then discard |
| `postgres_data` | Verify orphan status, then discard |

Anonymous volumes require root-assisted inspection. Classify them by labels, filesystem signature, last modification, size, and recognizable data. Ask for a new decision only when a volume can be associated with a meaningful project. Unidentified, unused volumes remain deletion candidates, not migration inputs.

The stopped `orgm-admin-minio-init` container appears to be a successful initialization job, not an orphan service.

## 11. Services Removed from the Existing Desktop-Oriented Server Profile

The current `nixos/server.nix` in the desktop repository was designed for Docker Compose and is not the future server implementation.

The new repository must not inherit:

- Docker 29;
- Docker Compose;
- Docker Buildx;
- lazydocker;
- ctop as Docker tooling;
- Docker pruning;
- backup paths under `/var/lib/docker/volumes`;
- auto-upgrade references to `/home/osmarg/Hobby/nixos#ero-server`;
- dependency on the desktop repository's `common.nix`, Home Manager, desktop profiles, gaming, audio, printing, Bluetooth, Flatpak, display managers, or graphical sessions.

Useful concepts such as SSH, fail2ban, firewall, Restic, Tailscale, and cleanup policy may be redesigned in `nixos-server`, not imported wholesale.

## 12. Update Policy

- The central `nixos-server/flake.lock` pins the complete deployed graph.
- Custom app repositories may release independently, but production changes only when the central lock updates.
- No floating application versions such as `latest` or `main`.
- Renovate or Dependabot may propose updates but cannot deploy automatically.
- Run checks and build the complete system before switching.
- Deploy manually in reviewed batches.
- NixOS generations provide configuration rollback.
- Application schema and data migrations require an independent rollback plan.

## 13. Verification Strategy

## 13.1 Repository checks

- `nix flake check`;
- format and lint checks;
- evaluate `nixosConfigurations.or-gm`;
- build the full system closure;
- verify required sops secret names without exposing values;
- assert absence of Docker, containerd, Compose, CasaOS, and OCI containers;
- assert every enabled service has data, network, backup, and health metadata.

## 13.2 VM tests

Use NixOS VM tests where practical for:

- boot and user creation;
- SSH and firewall policy;
- secret ownership;
- service startup ordering;
- local health endpoints;
- Cloudflared configuration generation;
- native service data directories;
- failure/restart behavior.

Hardware-dependent media and disk tests run on the actual host or staging hardware.

## 13.3 Migration checks

Every migrated service requires:

- source snapshot or dump;
- target checksum/validation;
- successful startup;
- application-level health check;
- login or representative functional test;
- reboot persistence test;
- documented rollback;
- restoration test for critical data.

## 14. Implementation Phases

### Phase 0: preserve the Arch host

1. Obtain root-assisted volume sizes, owners, labels, and content signatures.
2. Resolve all anonymous volumes.
3. Create the migration manifest and script.
4. Migrate approved durable data to canonical paths, one stack per nighttime window.
5. Archive approved retired projects.
6. Verify backup and restoration artifacts.
7. Keep Arch and Docker running until all required data is normalized.

### Phase 1: create `nixos-server`

1. Initialize independent Git repository at `/home/osmarg/Code/nixos-server`.
2. Add minimal flake and lock.
3. Add `or-gm` hardware, disk, user, network, SSH, Tailscale, Cloudflared, firewall, sops-nix, and Restic modules.
4. Add approved native service modules, initially disabled or staged as necessary.
5. Add tests and runbooks.
6. Do not depend on the desktop NixOS repository.

### Phase 2: validate without installing

1. Evaluate and build the complete configuration.
2. Run VM tests.
3. Audit closure and enabled units.
4. Validate secret inventory.
5. Confirm no Docker/runtime dependencies.
6. Produce installation and rollback checklist.

### Phase 3: install the base system

1. Verify temporary `sdb` backups and restoration tests.
2. Record both disk identities and UUIDs.
3. Format only `sda`.
4. Install minimal NixOS.
5. Mount existing `sdb` at `/home`.
6. Confirm console, SSH, Tailscale, DNS, firewall, time, storage, and secrets.
7. Reboot and verify base system before enabling applications.

### Phase 4: enable native services in batches

Suggested order:

1. storage, users/groups, networking, backups;
2. database primitives and standalone Redis;
3. Vaultwarden and Pi-hole;
4. qBittorrent, pyLoad, Sonarr, Radarr, Prowlarr, Bazarr;
5. Jellyfin and hardware acceleration;
6. Immich and Paperless-ngx;
7. MicroBin, Open WebUI, registry;
8. Homepage and Uptime Kuma;
9. remaining native services.

For every batch: build, switch, health check, reboot, and verify rollback.

### Phase 5: develop and enable stack flakes

Process one application repository at a time:

1. inspect source and current Compose behavior;
2. design package/module contract;
3. add package, NixOS module, checks, and migration tool;
4. test in staging;
5. tag or pin a revision;
6. add as `nixos-server` input;
7. migrate data;
8. enable service and ingress;
9. verify reboot and restore;
10. retire old deployment artifacts.

## 15. Completion Criteria

Migration is complete only when:

- `or-gm` boots from NixOS on `sda`;
- `sdb` is mounted intact at `/home`;
- approved persistent data uses canonical paths;
- every approved service is declared by `nixos-server` directly or through a pinned imported module;
- every approved service starts after reboot;
- Docker, containerd, Compose, CasaOS, Portainer, Watchtower, and dockerproxy are absent;
- no production service depends on a floating image tag;
- public ports match documented exceptions;
- private services remain private;
- Cloudflared and Tailscale are operational;
- Homepage reflects the real declarative catalog without Docker access;
- critical backups exist locally and on the VPS;
- critical restoration tests pass;
- rollback and recovery runbooks are complete;
- PiKVM remains documented as a future improvement.
