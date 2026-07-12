# OR-GM Arch Volume and Persistent Data Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and use a safe, manifest-driven tool that inventories Docker data on Arch Linux and migrates one approved service at a time from root-disk Docker volumes into `/home/osmarg/services` before NixOS installation.

**Architecture:** A Python standard-library CLI runs directly on `or-gm` with root privileges. It consumes an explicit JSON manifest, defaults to read-only audit mode, records machine-readable reports, and requires separate `prepare`, `copy`, `verify`, and `activate` operations so no command silently performs the complete migration. The tool never deletes source volumes; cleanup remains a later manual plan after NixOS restoration succeeds.

**Tech Stack:** Python 3 standard library, Docker CLI on existing Arch host, rsync, systemd/Compose commands, JSON manifests, unittest, shell integration tests, SHA-256, PostgreSQL/MariaDB/MongoDB/Redis/MinIO-specific dump commands where required.

## Global Constraints

- Do not stop any service while implementing or testing audit mode.
- Do not copy production data until its manifest entry is approved.
- Process exactly one logical service stack per migration execution.
- Run destructive-looking operations only during a user-approved nighttime maintenance window.
- Never delete a source Docker volume or bind directory.
- Never format, repartition, or alter `sdb`.
- Canonical destination root is `/home/osmarg/services/<service>`.
- Preserve source data until NixOS deployment and restoration are accepted.
- Exclude caches, builds, `node_modules`, machine-learning model caches, Docker overlay data, and ordinary logs unless explicitly approved.
- Produce logical database dumps before filesystem copies.
- Every activation requires a functional health check and documented rollback.
- Secrets and raw environment values must never appear in reports, Git, or command logs.
- The initial repository is `/home/osmarg/Code/nixos-server`, independent from `/home/osmarg/Hobby/nixos`.

---

## File Structure

```text
/home/osmarg/Code/nixos-server/
├── .gitignore
├── README.md
└── migrations/volume-migration/
    ├── README.md
    ├── pyproject.toml
    ├── src/or_gm_volume_migrate/
    │   ├── __init__.py
    │   ├── cli.py
    │   ├── command.py
    │   ├── manifest.py
    │   ├── inventory.py
    │   ├── preflight.py
    │   ├── migration.py
    │   ├── verification.py
    │   └── report.py
    ├── manifests/
    │   ├── schema.json
    │   ├── services.json
    │   └── orphan-decisions.json
    ├── tests/
    │   ├── test_manifest.py
    │   ├── test_inventory.py
    │   ├── test_preflight.py
    │   ├── test_migration.py
    │   ├── test_verification.py
    │   └── fixtures/
    │       ├── docker-inspect.json
    │       ├── docker-volumes.json
    │       └── manifest-valid.json
    └── reports/.gitkeep
```

Responsibilities:

- `command.py`: subprocess boundary; injectable runner for tests.
- `manifest.py`: strict parsing and validation of service entries.
- `inventory.py`: read-only Docker/container/mount discovery.
- `preflight.py`: disk, mount, process, target, and permission gates.
- `migration.py`: prepare, dump, stop, rsync, and activation orchestration.
- `verification.py`: file, dump, mount, container, and HTTP/TCP checks.
- `report.py`: redacted JSON report writer.
- `services.json`: approved service migration entries only.
- `orphan-decisions.json`: archive/discard/inspect decisions, never automatic deletion.

---

### Task 1: Create the Independent Repository and Python Package

**Files:**
- Create: `/home/osmarg/Code/nixos-server/.gitignore`
- Create: `/home/osmarg/Code/nixos-server/README.md`
- Create: `/home/osmarg/Code/nixos-server/migrations/volume-migration/pyproject.toml`
- Create: `/home/osmarg/Code/nixos-server/migrations/volume-migration/src/or_gm_volume_migrate/__init__.py`
- Create: `/home/osmarg/Code/nixos-server/migrations/volume-migration/reports/.gitkeep`

**Interfaces:**
- Produces: installable package `or_gm_volume_migrate` and command `or-gm-volume-migrate`.
- Consumes: Python 3.11 or newer; no third-party runtime dependencies.

- [ ] **Step 1: Create repository directories**

Run:

```bash
mkdir -p /home/osmarg/Code/nixos-server/migrations/volume-migration/{src/or_gm_volume_migrate,manifests,tests/fixtures,reports}
cd /home/osmarg/Code/nixos-server
git init
```

Expected: empty Git repository initialized at `/home/osmarg/Code/nixos-server/.git`.

- [ ] **Step 2: Write `.gitignore`**

```gitignore
__pycache__/
*.py[cod]
.venv/
.pytest_cache/
reports/*.json
reports/*.log
!reports/.gitkeep
*.dump
*.tar
*.tar.gz
.env
*.secret
```

- [ ] **Step 3: Write root `README.md`**

```markdown
# nixos-server

Declarative configuration and migration tooling for `or-gm`.

Current phase: Arch Linux persistent-data inventory and migration preparation.
No NixOS installation or production service migration is automated by default.
```

- [ ] **Step 4: Write `pyproject.toml`**

```toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[project]
name = "or-gm-volume-migrate"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = []

[project.scripts]
or-gm-volume-migrate = "or_gm_volume_migrate.cli:main"

[tool.setuptools]
package-dir = {"" = "src"}

[tool.setuptools.packages.find]
where = ["src"]
```

- [ ] **Step 5: Write package marker**

```python
"""Safe persistent-data migration tooling for or-gm."""

__version__ = "0.1.0"
```

- [ ] **Step 6: Create virtual environment and install editable package**

Run:

```bash
cd /home/osmarg/Code/nixos-server/migrations/volume-migration
python -m venv .venv
.venv/bin/pip install -e .
```

Expected: package installs without downloading runtime dependencies.

- [ ] **Step 7: Commit repository scaffold**

```bash
cd /home/osmarg/Code/nixos-server
git add .gitignore README.md migrations/volume-migration
 git commit -m "chore: initialize server migration repository"
```

Expected: first commit contains only scaffold files.

---

### Task 2: Implement the Command Runner Boundary

**Files:**
- Create: `migrations/volume-migration/src/or_gm_volume_migrate/command.py`
- Create: `migrations/volume-migration/tests/test_command.py`

**Interfaces:**
- Produces: `CommandResult`, `CommandError`, `Runner.run(argv, *, input_text=None, check=True, timeout=None)`.
- Consumes: argument arrays only; shell strings are forbidden.

- [ ] **Step 1: Write failing command runner tests**

```python
import unittest

from or_gm_volume_migrate.command import CommandError, Runner


class RunnerTest(unittest.TestCase):
    def test_returns_stdout_without_shell(self):
        result = Runner().run(["printf", "%s", "hello"])
        self.assertEqual(result.stdout, "hello")
        self.assertEqual(result.returncode, 0)

    def test_raises_redacted_error(self):
        with self.assertRaises(CommandError) as caught:
            Runner().run(["sh", "-c", "printf secret >&2; exit 7"])
        self.assertEqual(caught.exception.returncode, 7)
        self.assertNotIn("secret", str(caught.exception))
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
cd /home/osmarg/Code/nixos-server/migrations/volume-migration
.venv/bin/python -m unittest tests.test_command -v
```

Expected: FAIL because `or_gm_volume_migrate.command` does not exist.

- [ ] **Step 3: Implement command runner**

```python
from __future__ import annotations

from dataclasses import dataclass
import subprocess
from typing import Sequence


@dataclass(frozen=True)
class CommandResult:
    argv: tuple[str, ...]
    returncode: int
    stdout: str


class CommandError(RuntimeError):
    def __init__(self, argv: Sequence[str], returncode: int):
        self.argv = tuple(argv)
        self.returncode = returncode
        super().__init__(f"command failed with exit code {returncode}: {self.argv[0]}")


class Runner:
    def run(
        self,
        argv: Sequence[str],
        *,
        input_text: str | None = None,
        check: bool = True,
        timeout: int | None = None,
    ) -> CommandResult:
        if not argv:
            raise ValueError("argv must not be empty")
        completed = subprocess.run(
            list(argv),
            input=input_text,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=False,
            timeout=timeout,
            check=False,
        )
        if check and completed.returncode != 0:
            raise CommandError(argv, completed.returncode)
        return CommandResult(tuple(argv), completed.returncode, completed.stdout)
```

- [ ] **Step 4: Run command tests**

Run:

```bash
.venv/bin/python -m unittest tests.test_command -v
```

Expected: 2 tests PASS; stderr content never enters exception message.

- [ ] **Step 5: Commit**

```bash
git add migrations/volume-migration/src/or_gm_volume_migrate/command.py migrations/volume-migration/tests/test_command.py
git commit -m "feat: add redacted command runner"
```

---

### Task 3: Define and Validate the Migration Manifest

**Files:**
- Create: `migrations/volume-migration/src/or_gm_volume_migrate/manifest.py`
- Create: `migrations/volume-migration/manifests/schema.json`
- Create: `migrations/volume-migration/tests/test_manifest.py`
- Create: `migrations/volume-migration/tests/fixtures/manifest-valid.json`

**Interfaces:**
- Produces: `MountSpec`, `DumpSpec`, `HealthSpec`, `ServiceSpec`, `Manifest`, `load_manifest(path: Path) -> Manifest`.
- Consumes: JSON with schema version `1`; canonical destination under `/home/osmarg/services`.

- [ ] **Step 1: Write valid fixture**

```json
{
  "schemaVersion": 1,
  "destinationRoot": "/home/osmarg/services",
  "services": [
    {
      "id": "example",
      "composeFiles": ["/home/osmarg/example/docker-compose.yml"],
      "projectDirectory": "/home/osmarg/example",
      "destinations": [
        {
          "sourceType": "volume",
          "source": "example_data",
          "target": "/home/osmarg/services/example/data/app",
          "durability": "critical"
        }
      ],
      "dumps": [],
      "health": {"type": "http", "target": "http://127.0.0.1:18080/health", "expectedStatus": 200}
    }
  ]
}
```

- [ ] **Step 2: Write failing validation tests**

```python
import json
from pathlib import Path
import tempfile
import unittest

from or_gm_volume_migrate.manifest import ManifestError, load_manifest


class ManifestTest(unittest.TestCase):
    def test_loads_valid_manifest(self):
        manifest = load_manifest(Path("tests/fixtures/manifest-valid.json"))
        self.assertEqual(manifest.services[0].id, "example")

    def test_rejects_target_outside_canonical_root(self):
        raw = json.loads(Path("tests/fixtures/manifest-valid.json").read_text())
        raw["services"][0]["destinations"][0]["target"] = "/tmp/escape"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.json"
            path.write_text(json.dumps(raw))
            with self.assertRaisesRegex(ManifestError, "outside destination root"):
                load_manifest(path)

    def test_rejects_duplicate_service_ids(self):
        raw = json.loads(Path("tests/fixtures/manifest-valid.json").read_text())
        raw["services"].append(raw["services"][0])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.json"
            path.write_text(json.dumps(raw))
            with self.assertRaisesRegex(ManifestError, "duplicate service id"):
                load_manifest(path)
```

- [ ] **Step 3: Run tests and verify failure**

Run:

```bash
.venv/bin/python -m unittest tests.test_manifest -v
```

Expected: FAIL because manifest module does not exist.

- [ ] **Step 4: Implement strict dataclasses and parser**

Implement these exact types:

```python
@dataclass(frozen=True)
class MountSpec:
    source_type: Literal["volume", "bind"]
    source: str
    target: Path
    durability: Literal["critical", "durable", "regenerable"]

@dataclass(frozen=True)
class DumpSpec:
    kind: Literal["postgres", "mariadb", "mongodb", "redis", "minio"]
    container: str
    output: Path
    command: tuple[str, ...]

@dataclass(frozen=True)
class HealthSpec:
    type: Literal["http", "tcp", "command"]
    target: str
    expected_status: int | None

@dataclass(frozen=True)
class ServiceSpec:
    id: str
    compose_files: tuple[Path, ...]
    project_directory: Path
    destinations: tuple[MountSpec, ...]
    dumps: tuple[DumpSpec, ...]
    health: HealthSpec

@dataclass(frozen=True)
class Manifest:
    schema_version: Literal[1]
    destination_root: Path
    services: tuple[ServiceSpec, ...]
```

Validation must reject:

- schema versions other than `1`;
- empty service IDs;
- duplicate service IDs;
- relative source/target/project paths where absolute paths are required;
- targets outside `/home/osmarg/services`;
- duplicate targets;
- unknown keys at every object level;
- shell-string dump commands instead of arrays;
- dump outputs outside the service's `backups` directory;
- a manifest with zero services.

Use only `json`, `dataclasses`, `pathlib`, and `typing`.

- [ ] **Step 5: Write `schema.json` matching parser rules**

Define JSON Schema draft 2020-12 with `additionalProperties: false` at every object, enums matching the dataclasses, and `schemaVersion` fixed to `1`.

- [ ] **Step 6: Run manifest tests**

Run:

```bash
.venv/bin/python -m unittest tests.test_manifest -v
```

Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add migrations/volume-migration/manifests/schema.json migrations/volume-migration/src/or_gm_volume_migrate/manifest.py migrations/volume-migration/tests
git commit -m "feat: validate explicit migration manifests"
```

---

### Task 4: Implement Read-Only Docker Inventory

**Files:**
- Create: `migrations/volume-migration/src/or_gm_volume_migrate/inventory.py`
- Create: `migrations/volume-migration/tests/test_inventory.py`
- Create: `migrations/volume-migration/tests/fixtures/docker-inspect.json`
- Create: `migrations/volume-migration/tests/fixtures/docker-volumes.json`

**Interfaces:**
- Produces: `ContainerMount`, `ContainerInfo`, `VolumeInfo`, `Inventory`, `collect_inventory(runner: Runner) -> Inventory`.
- Consumes: `docker ps`, `docker inspect`, `docker volume ls`, and `docker volume inspect`; no writes.

- [ ] **Step 1: Create fixtures representing volume, bind, cache, and orphan cases**

Fixture must include:

- PostgreSQL named volume used by one container;
- bind mount under `/home/osmarg`;
- anonymous volume used for `node_modules`;
- named volume with no container;
- volume path under `/var/lib/docker/volumes`.

- [ ] **Step 2: Write failing inventory tests**

Test exact behavior:

```python
self.assertEqual(inventory.active_volumes["example_pgdata"].containers, ("example-db",))
self.assertIn("orphan_data", inventory.orphan_volumes)
self.assertEqual(inventory.containers["example-app"].compose_project, "example")
self.assertTrue(inventory.containers["example-app"].mounts[0].writable)
```

Also assert generated command vectors contain only read-only Docker subcommands.

- [ ] **Step 3: Run tests and verify failure**

Run:

```bash
.venv/bin/python -m unittest tests.test_inventory -v
```

Expected: FAIL because inventory module does not exist.

- [ ] **Step 4: Implement inventory collection**

Use Docker JSON formats and parse JSON in Python. Do not parse column-aligned human output. Collect:

- container name, image, state, Compose project/service/workdir/config files;
- mount type, source, destination, read/write flag;
- volume name, mountpoint, labels, attached containers;
- orphan status;
- anonymous hash-name status.

Do not read environment variables from container inspection.

- [ ] **Step 5: Run inventory tests**

Run:

```bash
.venv/bin/python -m unittest tests.test_inventory -v
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add migrations/volume-migration/src/or_gm_volume_migrate/inventory.py migrations/volume-migration/tests
git commit -m "feat: inventory Docker mounts without secrets"
```

---

### Task 5: Implement Preflight Safety Gates

**Files:**
- Create: `migrations/volume-migration/src/or_gm_volume_migrate/preflight.py`
- Create: `migrations/volume-migration/tests/test_preflight.py`

**Interfaces:**
- Produces: `PreflightIssue`, `PreflightReport`, `run_preflight(service, inventory, runner) -> PreflightReport`.
- Consumes: validated `ServiceSpec` and read-only `Inventory`.

- [ ] **Step 1: Write failing safety tests**

Cover these failures:

- process is not root;
- `/home` is not a mountpoint;
- `/home` UUID does not equal recorded `sdb` UUID;
- destination escapes canonical root after symlink resolution;
- target already exists and is non-empty;
- source volume is absent;
- source volume is attached to a container outside selected stack;
- free space is less than source size plus 20%;
- Compose file is missing;
- health target is public rather than loopback/Tailscale/LAN for an administrative service.

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
.venv/bin/python -m unittest tests.test_preflight -v
```

Expected: FAIL because preflight module does not exist.

- [ ] **Step 3: Implement non-mutating preflight**

`PreflightReport.ok` is true only when no issue has severity `error`. Every issue has stable code, message, and remediation. Required stable codes:

```text
NOT_ROOT
HOME_NOT_MOUNTED
HOME_UUID_MISMATCH
TARGET_ESCAPE
TARGET_NOT_EMPTY
SOURCE_MISSING
SOURCE_SHARED
INSUFFICIENT_SPACE
COMPOSE_MISSING
HEALTH_TARGET_UNSAFE
```

Read disk identity through `findmnt --json /home` and `lsblk --json`; do not infer from device names alone.

- [ ] **Step 4: Run tests**

Run:

```bash
.venv/bin/python -m unittest tests.test_preflight -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add migrations/volume-migration/src/or_gm_volume_migrate/preflight.py migrations/volume-migration/tests/test_preflight.py
git commit -m "feat: block unsafe volume migrations"
```

---

### Task 6: Implement Redacted Audit Reports

**Files:**
- Create: `migrations/volume-migration/src/or_gm_volume_migrate/report.py`
- Create: `migrations/volume-migration/tests/test_report.py`

**Interfaces:**
- Produces: `write_report(path: Path, payload: Mapping[str, object]) -> None`.
- Consumes: inventory/preflight result dictionaries without raw environment values.

- [ ] **Step 1: Write failing report tests**

Assert:

- report file mode is `0600`;
- write is atomic through temporary file and rename;
- keys matching `password`, `secret`, `token`, `credential`, `key`, and `env` are replaced with `"<redacted>"` recursively;
- report includes UTC timestamp and host name;
- report refuses paths outside `reports/`.

- [ ] **Step 2: Run and verify failure**

Run:

```bash
.venv/bin/python -m unittest tests.test_report -v
```

Expected: FAIL because report module does not exist.

- [ ] **Step 3: Implement report writer**

Use `json`, `os.open`, `tempfile`, `socket`, and `datetime`. Sort keys and indent output for review.

- [ ] **Step 4: Run tests**

Run:

```bash
.venv/bin/python -m unittest tests.test_report -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add migrations/volume-migration/src/or_gm_volume_migrate/report.py migrations/volume-migration/tests/test_report.py
git commit -m "feat: write redacted migration audit reports"
```

---

### Task 7: Implement Migration Operations Without Source Deletion

**Files:**
- Create: `migrations/volume-migration/src/or_gm_volume_migrate/migration.py`
- Create: `migrations/volume-migration/tests/test_migration.py`

**Interfaces:**
- Produces: `MigrationEngine.prepare`, `.dump`, `.stop`, `.copy`, `.start`, `.rollback_start`.
- Consumes: one `ServiceSpec`, `Runner`, and successful `PreflightReport`.

- [ ] **Step 1: Write failing orchestration tests**

Use fake runner and assert exact command order:

```text
preflight accepted
mkdir targets/backups
run dump commands
compose stop
rsync source to target
compose start
```

Assert:

- engine refuses more than one service;
- `copy` refuses when selected containers are still running;
- rsync arguments include `--archive --hard-links --acls --xattrs --numeric-ids --one-file-system`;
- source path has trailing slash and target path has trailing slash;
- no command contains `rm`, `docker volume rm`, `prune`, `down -v`, or filesystem formatting tools;
- dump output uses a temporary name and atomic rename;
- start operation is separate from copy operation.

- [ ] **Step 2: Run and verify failure**

Run:

```bash
.venv/bin/python -m unittest tests.test_migration -v
```

Expected: FAIL because migration module does not exist.

- [ ] **Step 3: Implement engine operations**

Compose command prefix:

```python
[
    "docker", "compose",
    *sum((["-f", str(path)] for path in service.compose_files), []),
    "--project-directory", str(service.project_directory),
]
```

Operational rules:

- `prepare`: create target and backup directories only after preflight success.
- `dump`: execute manifest command arrays inside named containers; never interpolate shell strings.
- `stop`: use `docker compose stop`, not `down`.
- `copy`: resolve named volume to its mountpoint, assert containers stopped, then rsync.
- `start`: use `docker compose up -d` only after Compose files have been manually reviewed and changed to bind targets.
- `rollback_start`: stop current stack, restore original Compose files from Git/manual backup, then start against source volumes.

Do not automate Compose edits in this first version. Human review of each stack file is a gate.

- [ ] **Step 4: Run migration tests**

Run:

```bash
.venv/bin/python -m unittest tests.test_migration -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add migrations/volume-migration/src/or_gm_volume_migrate/migration.py migrations/volume-migration/tests/test_migration.py
git commit -m "feat: orchestrate reversible service data copies"
```

---

### Task 8: Implement Verification Gates

**Files:**
- Create: `migrations/volume-migration/src/or_gm_volume_migrate/verification.py`
- Create: `migrations/volume-migration/tests/test_verification.py`

**Interfaces:**
- Produces: `VerificationResult`, `verify_files`, `verify_dump`, `verify_mounts`, `verify_health`.
- Consumes: one service manifest and command runner.

- [ ] **Step 1: Write failing verification tests**

Cover:

- source and target byte/file counts;
- SHA-256 manifest generation for regular files;
- PostgreSQL custom dump verification with `pg_restore --list`;
- MariaDB SQL dump non-empty and expected header;
- MongoDB archive non-empty;
- Redis RDB signature `REDIS`;
- MinIO object listing count when configured;
- container mount source equals canonical target after restart;
- HTTP expected status;
- TCP connection success;
- command health check exact zero exit;
- any failed check blocks completion.

- [ ] **Step 2: Run and verify failure**

Run:

```bash
.venv/bin/python -m unittest tests.test_verification -v
```

Expected: FAIL because verification module does not exist.

- [ ] **Step 3: Implement verification**

File verification produces a sorted relative-path/size/SHA-256 manifest. Allow an explicit exclusion list from the manifest only after schema is extended and tested; do not silently skip unreadable files.

Health checks must use Python `urllib.request` for HTTP and `socket.create_connection` for TCP. Command checks use `Runner` argument arrays.

- [ ] **Step 4: Run verification tests**

Run:

```bash
.venv/bin/python -m unittest tests.test_verification -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add migrations/volume-migration/src/or_gm_volume_migrate/verification.py migrations/volume-migration/tests/test_verification.py
git commit -m "feat: verify copied service data and health"
```

---

### Task 9: Implement the Safe CLI

**Files:**
- Create: `migrations/volume-migration/src/or_gm_volume_migrate/cli.py`
- Create: `migrations/volume-migration/tests/test_cli.py`

**Interfaces:**
- Produces command `or-gm-volume-migrate` with subcommands `inventory`, `preflight`, `prepare`, `dump`, `stop`, `copy`, `verify`, `start`, and `report`.
- Consumes `--manifest PATH` and exactly one `--service ID` for mutating subcommands.

- [ ] **Step 1: Write failing CLI tests**

Assert:

- no subcommand defaults to migration;
- inventory requires no service and performs only reads;
- mutating subcommands require root;
- mutating subcommands require `--service`;
- `--all` is rejected for mutating subcommands;
- `copy` requires typed confirmation equal to `COPY {service-id}`;
- `stop` requires typed confirmation equal to `STOP {service-id}`;
- command exits nonzero on failed preflight/verification;
- reports contain no environment values.

- [ ] **Step 2: Run and verify failure**

Run:

```bash
.venv/bin/python -m unittest tests.test_cli -v
```

Expected: FAIL because CLI module does not exist.

- [ ] **Step 3: Implement argparse CLI**

Required invocation examples:

```bash
or-gm-volume-migrate inventory --manifest manifests/services.json
sudo or-gm-volume-migrate preflight --manifest manifests/services.json --service orgm-admin
sudo or-gm-volume-migrate dump --manifest manifests/services.json --service orgm-admin
sudo or-gm-volume-migrate stop --manifest manifests/services.json --service orgm-admin
sudo or-gm-volume-migrate copy --manifest manifests/services.json --service orgm-admin
sudo or-gm-volume-migrate verify --manifest manifests/services.json --service orgm-admin
sudo or-gm-volume-migrate start --manifest manifests/services.json --service orgm-admin
```

CLI must print next safe action after every successful command. It must never chain stop, copy, and start automatically.

- [ ] **Step 4: Run complete unit suite**

Run:

```bash
.venv/bin/python -m unittest discover -s tests -v
```

Expected: all tests PASS.

- [ ] **Step 5: Verify command help**

Run:

```bash
.venv/bin/or-gm-volume-migrate --help
```

Expected: help lists all subcommands and states that source deletion is unsupported.

- [ ] **Step 6: Commit**

```bash
git add migrations/volume-migration/src/or_gm_volume_migrate/cli.py migrations/volume-migration/tests/test_cli.py
git commit -m "feat: add guarded volume migration CLI"
```

---

### Task 10: Encode Orphan Decisions and Produce Root Audit

**Files:**
- Create: `migrations/volume-migration/manifests/orphan-decisions.json`
- Create: `migrations/volume-migration/README.md`
- Create at runtime: `migrations/volume-migration/reports/or-gm-inventory-{UTC timestamp}.json` (ignored)

**Interfaces:**
- Produces reviewed root-assisted inventory; no filesystem changes.
- Consumes approved orphan decisions from design.

- [ ] **Step 1: Write orphan decision manifest**

```json
{
  "schemaVersion": 1,
  "decisions": {
    "authentik_database": "archive",
    "docker-registry_prometheus-data": "inspect-discard-metrics",
    "n8n_data": "archive-with-n8n",
    "nginx-data": "preserve-legacy",
    "nginx-letsencrypt": "preserve-legacy",
    "orgm_img": "verify-discard",
    "orgm_portada": "verify-discard",
    "postgres_data": "verify-orphan-discard"
  },
  "anonymousPolicy": "inspect-and-escalate-recognizable-data"
}
```

- [ ] **Step 2: Write operator README**

Document prerequisites, commands, report location, nighttime gate, source preservation, rollback, and explicit prohibition of `docker volume prune`.

- [ ] **Step 3: Copy repository to or-gm or clone it there**

Run from workstation after a remote Git origin exists, or use rsync without secrets:

```bash
rsync -a --delete --exclude .venv --exclude reports/*.json /home/osmarg/Code/nixos-server/ or-gm:/home/osmarg/Code/nixos-server/
```

Expected: source code arrives; production reports and virtualenv do not transfer.

- [ ] **Step 4: Install tool on Arch host**

Run:

```bash
ssh -t or-gm 'cd /home/osmarg/Code/nixos-server/migrations/volume-migration && python -m venv .venv && .venv/bin/pip install -e .'
```

Expected: editable package installs.

- [ ] **Step 5: Run root inventory only**

Run interactively:

```bash
ssh -t or-gm 'cd /home/osmarg/Code/nixos-server/migrations/volume-migration && sudo .venv/bin/or-gm-volume-migrate inventory --manifest manifests/services.json'
```

Expected: report includes volume sizes, owners, mountpoints, labels, consumers, last modification, and orphan classification; no containers stop.

- [ ] **Step 6: Review anonymous volumes one by one**

For every anonymous volume, record:

- attached container: none;
- filesystem signature;
- top-level names;
- byte size;
- newest modification;
- likely project;
- recommendation.

Escalate recognizable data to user. Do not delete anything.

- [ ] **Step 7: Commit documentation and decisions**

```bash
git add migrations/volume-migration/README.md migrations/volume-migration/manifests/orphan-decisions.json
git commit -m "docs: record orphan volume decisions"
```

---

### Task 11: Build the Initial Approved Service Manifest

**Files:**
- Create: `migrations/volume-migration/manifests/services.json`
- Create: `migrations/volume-migration/tests/test_production_manifest.py`

**Interfaces:**
- Produces migration entries for durable data only.
- Consumes root audit and approved service catalog.

- [ ] **Step 1: Write failing production-manifest test**

Test must assert exact required service IDs:

```python
REQUIRED = {
    "dagendang",
    "immich",
    "jellyfin",
    "open-webui",
    "orgm-admin",
    "orgm-seguimiento",
    "registry",
    "redis-standalone",
    "romm",
    "vaultwarden",
    "webodm",
}
```

Also assert excluded IDs are absent:

```python
EXCLUDED = {
    "2fauth", "adminer", "appsmith", "dashy", "healthchecks",
    "insforge", "librechat", "portainer", "watchtower",
}
```

- [ ] **Step 2: Run and verify failure**

Run:

```bash
.venv/bin/python -m unittest tests.test_production_manifest -v
```

Expected: FAIL because production manifest does not exist.

- [ ] **Step 3: Populate entries from root audit**

For every required service, encode exact observed Compose files, project directory, durable volume/bind sources, canonical targets, dumps, and local health check.

Do not guess credentials or database names. Obtain non-secret identifiers from Compose configuration and Docker labels; reference credential files through existing runtime paths without copying values into JSON.

Do not add services whose data already resides canonically under `/home/osmarg/services` unless a path normalization is still required.

- [ ] **Step 4: Add archived-service entries to a separate archive report, not services manifest**

Record Authentik and n8n archive procedures in operator documentation. They must not be accepted by migration commands intended for future active services.

- [ ] **Step 5: Run manifest and full test suite**

Run:

```bash
.venv/bin/python -m unittest discover -s tests -v
```

Expected: all tests PASS and required/excluded sets match.

- [ ] **Step 6: Commit**

```bash
git add migrations/volume-migration/manifests/services.json migrations/volume-migration/tests/test_production_manifest.py
git commit -m "feat: declare approved persistent data migrations"
```

---

### Task 12: Pilot a Low-Risk Durable Service Migration

**Files:**
- Modify: one selected service's existing Compose file on `or-gm`
- Create at runtime: canonical service target and reports (not Git)
- Modify: `migrations/volume-migration/README.md` with pilot results

**Interfaces:**
- Produces proven operational workflow.
- Consumes approved manifest, tested CLI, nighttime window, and user-selected pilot.

- [ ] **Step 1: Approve Open WebUI as pilot**

Use `open-webui` because it is an approved native future service with one persistent application-data volume and a local HTTP health target. Before downtime, confirm remote-provider login works and produce a verified copy of user/chat data. If either check fails, stop this task and revise the manifest; do not substitute another service without a reviewed plan change.

- [ ] **Step 2: Run preflight and save report**

```bash
sudo .venv/bin/or-gm-volume-migrate preflight --manifest manifests/services.json --service open-webui
```

Expected: PASS with `/home` UUID, capacity, source ownership, target, and stack consumers shown.

- [ ] **Step 3: Create dump if manifest requires it**

```bash
sudo .venv/bin/or-gm-volume-migrate dump --manifest manifests/services.json --service open-webui
```

Expected: verified backup artifact in `/home/osmarg/services/open-webui/backups`.

- [ ] **Step 4: Stop only pilot stack**

```bash
sudo .venv/bin/or-gm-volume-migrate stop --manifest manifests/services.json --service open-webui
```

Type exact confirmation requested. Expected: only Open WebUI stops.

- [ ] **Step 5: Copy data**

```bash
sudo .venv/bin/or-gm-volume-migrate copy --manifest manifests/services.json --service open-webui
```

Expected: rsync completes; original volume remains intact.

- [ ] **Step 6: Verify offline copy**

```bash
sudo .venv/bin/or-gm-volume-migrate verify --manifest manifests/services.json --service open-webui
```

Expected: file/backup verification passes; health check is reported pending while stopped.

- [ ] **Step 7: Manually edit and review Compose bind mount**

Read the exact Compose file path from the validated manifest, replace only the selected persistent named volume with `/home/osmarg/services/open-webui/data/app`, and save a timestamped copy of the original file. Validate every listed Compose file without printing resolved environment values:

```bash
cd /home/osmarg/Code/nixos-server/migrations/volume-migration
.venv/bin/python - <<'PY'
from pathlib import Path
import subprocess
from or_gm_volume_migrate.manifest import load_manifest
manifest = load_manifest(Path("manifests/services.json"))
service = next(item for item in manifest.services if item.id == "open-webui")
argv = ["docker", "compose"]
for compose_file in service.compose_files:
    argv.extend(["-f", str(compose_file)])
argv.extend(["--project-directory", str(service.project_directory), "config", "--quiet"])
subprocess.run(argv, check=True, shell=False)
PY
```

Expected: every Compose file listed by the manifest validates without emitting resolved configuration or secrets.

- [ ] **Step 8: Start pilot and verify health**

```bash
sudo .venv/bin/or-gm-volume-migrate start --manifest manifests/services.json --service open-webui
sudo .venv/bin/or-gm-volume-migrate verify --manifest manifests/services.json --service open-webui
```

Expected: mounts point to canonical target and health check passes.

- [ ] **Step 9: Test rollback procedure without deleting target**

During same window, stop pilot, restore original Compose mount, start against original source, and verify health. Then repeat activation to canonical target if rollback succeeds.

Expected: both source and target startup paths work.

- [ ] **Step 10: Record pilot evidence and commit documentation**

Document timestamps, downtime, byte counts, checksums, health result, rollback result, and unresolved issues without secrets.

```bash
git add migrations/volume-migration/README.md
git commit -m "docs: record pilot data migration"
```

---

### Task 13: Migrate Approved Durable Services One by One

**Files:**
- Modify: each approved service's current Compose files on Arch
- Modify: `migrations/volume-migration/manifests/services.json` only when audit evidence requires correction
- Modify: `migrations/volume-migration/README.md` migration ledger

**Interfaces:**
- Produces canonical durable data paths for every approved service.
- Consumes pilot-proven workflow.

- [ ] **Step 1: Order migrations by risk**

Use this sequence unless audit findings require stricter dependency ordering:

1. Open WebUI;
2. standalone Redis after consumer identification;
3. registry;
4. ROMM;
5. Dagendang;
6. ORGM Seguimiento;
7. ORGM Admin;
8. WebODM;
9. Immich;
10. Vaultwarden.

Jellyfin media already resides under `/home`; migrate only non-canonical metadata/configuration. Vaultwarden remains last and requires successful restore before any root-disk reinstall.

- [ ] **Step 2: Execute full pilot workflow for one service per window**

For each ID, run preflight, dump, stop, copy, offline verification, manual Compose review, start, online verification, reboot-persistence check when appropriate, and rollback test.

Expected: one migration ledger entry per service; no source deletions.

- [ ] **Step 3: Archive Authentik and n8n in separate windows**

Authentik: produce recoverable PostgreSQL export or volume archive, checksum it, record software/database version, and do not relaunch.

n8n: preserve PostgreSQL dump, workflow data, encrypted credentials, encryption key, version, and sanitized Compose configuration; test restoration in an isolated temporary environment; then retire.

- [ ] **Step 4: Preserve legacy nginx volumes**

Copy `nginx-data` and `nginx-letsencrypt` to:

```text
/home/osmarg/services/archive/nginx-legacy/data
/home/osmarg/services/archive/nginx-legacy/letsencrypt
```

Create checksums and a metadata report. Do not treat archive as an active service.

- [ ] **Step 5: Mark discard candidates without deleting**

Record approved discard status for metrics, ORGM img/portada, generic PostgreSQL, rejected service volumes, and unrecognized anonymous volumes. Physical deletion is out of scope.

- [ ] **Step 6: Run final inventory**

Expected final report:

- every approved durable root-disk volume has canonical copy;
- archived projects have verified artifacts;
- discard candidates remain identifiable;
- no required migration depends on `/var/lib/docker/volumes` on `sda`;
- source volumes still exist.

- [ ] **Step 7: Commit migration ledger**

```bash
git add migrations/volume-migration/README.md migrations/volume-migration/manifests/services.json
git commit -m "docs: complete Arch persistent data migration ledger"
```

---

### Task 14: Gate Handoff to the NixOS Repository Plan

**Files:**
- Create: `docs/runbooks/arch-data-handoff.md` in `/home/osmarg/Code/nixos-server`

**Interfaces:**
- Produces immutable evidence required by the next plan.
- Consumes final inventory and migration ledger.

- [ ] **Step 1: Write handoff with exact evidence**

Include:

- `sda` and `sdb` model, serial, UUID, filesystem, and mountpoint;
- canonical service path inventory;
- database engine/version per stack;
- dump and checksum paths;
- archive paths;
- service decisions;
- remaining Docker source volumes;
- open risks;
- restoration test results;
- explicit statement that `sdb` must not be formatted.

- [ ] **Step 2: Verify no secrets entered Git**

Run:

```bash
git grep -n -i -E '(password|secret|token|api[_-]?key|private[_-]?key)\s*[:=]\s*[^<]' -- . ':!*.md'
```

Expected: no plaintext secret assignments. Review Markdown matches manually because words such as “secret” are expected in documentation.

- [ ] **Step 3: Run final test suite**

```bash
cd /home/osmarg/Code/nixos-server/migrations/volume-migration
.venv/bin/python -m unittest discover -s tests -v
```

Expected: all tests PASS.

- [ ] **Step 4: Verify repository state**

```bash
cd /home/osmarg/Code/nixos-server
git status --short
git log --oneline --decorate -15
```

Expected: clean worktree; granular commits for scaffold, runner, manifest, inventory, preflight, reports, migration, verification, CLI, decisions, production manifest, pilot, migration ledger, and handoff.

- [ ] **Step 5: Commit handoff**

```bash
git add docs/runbooks/arch-data-handoff.md
git commit -m "docs: hand off persistent data for NixOS migration"
```

- [ ] **Step 6: Stop and request approval for next plan**

Do not install NixOS. Present handoff evidence and request explicit approval to write/execute the independent `nixos-server` base-system implementation plan.
