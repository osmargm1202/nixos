# orgm-hypr Dotfiles Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `orgm-hypr` clone `https://github.com/osmargm1202/dotfiles` into `~/Hobby/dotfiles` on first command run when that directory is missing, while leaving existing dotfiles and theme config untouched.

**Architecture:** Add one focused startup bootstrap helper in `cmd/orgm-hypr` and call it once from `runWithIO` after validating that a command was provided and before dispatching subcommands. The helper resolves `HOME`, checks `$HOME/Hobby/dotfiles`, creates only `$HOME/Hobby` when needed, then runs guarded `git clone`; existing target directory returns success with no mutation.

**Tech Stack:** Go 1.23, standard library only (`os`, `os/exec`, `path/filepath`, `strings`, `fmt`, `io` already present in main), existing `go test` package tests, existing Bash/Bats smoke test style.

---

## Repository Pattern Notes

- `cmd/orgm-hypr/main.go` owns CLI dispatch via `runWithIO(args, stdout, stderr)` and returns errors for `main()` to print through `cli.PrintError`.
- Existing CLI tests live in package `main` under `cmd/orgm-hypr/*_test.go`, call `runWithIO`, and use helper functions already defined in `main_test.go`: `writeExecutable`, `writeFileAt`, `readFile`, and `assertUsageError`.
- Existing tests isolate filesystem behavior with `t.TempDir()` and environment overrides through `t.Setenv`.
- `tests/orgm-hypr.bats.sh` builds the binary and performs command-level smoke tests.

## Exact Files

- Create: `cmd/orgm-hypr/dotfiles_bootstrap.go`
  - Responsibility: resolve target path, skip existing target directory, clone missing dotfiles repository, return clear errors.
- Create: `cmd/orgm-hypr/dotfiles_bootstrap_test.go`
  - Responsibility: verify clone, skip/no-overwrite, and clone-failure behavior through `runWithIO`.
- Modify: `cmd/orgm-hypr/main.go:41-47`
  - Responsibility: call bootstrap after missing-command usage check and before subcommand switch.
- Modify only during plan creation: `docs/superpowers/plans/2026-05-28-orgm-hypr-dotfiles.md`

## Constants and Behavior Contract

- Repository URL: `https://github.com/osmargm1202/dotfiles`
- Target directory: `filepath.Join(os.Getenv("HOME"), "Hobby", "dotfiles")`
- Parent directory created only when target is missing: `filepath.Join(os.Getenv("HOME"), "Hobby")`
- Existing target behavior: return `nil`; do not call `git`; do not inspect or edit contents.
- Failure behavior: return non-nil error containing repository URL, target path, and git stderr/stdout text.
- Config non-mutation behavior: bootstrap never opens or writes `config/dotfiles.json`, `~/.config/orgm-hypr/themes.json`, generated theme files, or registry entries.

---

### Task 1: Add failing bootstrap coverage

**Files:**
- Create: `cmd/orgm-hypr/dotfiles_bootstrap_test.go`
- Test: `cmd/orgm-hypr/dotfiles_bootstrap_test.go`

- [ ] **Step 1: Write failing tests**

Create `cmd/orgm-hypr/dotfiles_bootstrap_test.go` with this complete content:

```go
package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const expectedDotfilesRepoURL = "https://github.com/osmargm1202/dotfiles"

func TestOrgmHyprBootstrapClonesMissingDotfilesBeforeCommand(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	bin := filepath.Join(root, "bin")
	logPath := filepath.Join(root, "git.log")
	gitPath := filepath.Join(bin, "git")
	writeExecutable(t, gitPath, "#!/bin/sh\nprintf '%s\\n' \"$*\" >>\"$ORGM_TEST_LOG\"\nif [ \"$1\" = clone ]; then\n\tmkdir -p \"$3\"\n\texit 0\nfi\nexit 9\n")
	t.Setenv("HOME", home)
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("ORGM_TEST_LOG", logPath)
	var stdout, stderr bytes.Buffer

	err := runWithIO([]string{"version"}, &stdout, &stderr)

	if err != nil {
		t.Fatalf("runWithIO(version) error = %v", err)
	}
	if got, want := stdout.String(), "orgm-hypr dev\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
	if got := stderr.String(); got != "" {
		t.Fatalf("stderr = %q, want empty", got)
	}
	target := filepath.Join(home, "Hobby", "dotfiles")
	if _, err := os.Stat(target); err != nil {
		t.Fatalf("dotfiles target stat error = %v, want created", err)
	}
	if got, want := readFile(t, logPath), "clone "+expectedDotfilesRepoURL+" "+target+"\n"; got != want {
		t.Fatalf("git log = %q, want %q", got, want)
	}
}

func TestOrgmHyprBootstrapSkipsExistingDotfilesAndPreservesConfig(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	bin := filepath.Join(root, "bin")
	logPath := filepath.Join(root, "git.log")
	dotfilesDir := filepath.Join(home, "Hobby", "dotfiles")
	dotfilesConfig := filepath.Join(dotfilesDir, "config", "dotfiles.json")
	themeRegistry := filepath.Join(home, ".config", "orgm-hypr", "themes.json")
	writeFileAt(t, filepath.Join(dotfilesDir, "sentinel.txt"), "keep-dotfiles-dir")
	writeFileAt(t, dotfilesConfig, "{\"sentinel\":\"dotfiles-config\"}\n")
	writeFileAt(t, themeRegistry, "{\"sentinel\":\"theme-registry\"}\n")
	dotfilesBefore := readFile(t, dotfilesConfig)
	themeBefore := readFile(t, themeRegistry)
	writeExecutable(t, filepath.Join(bin, "git"), "#!/bin/sh\necho git-called >>\"$ORGM_TEST_LOG\"\nexit 99\n")
	t.Setenv("HOME", home)
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("ORGM_TEST_LOG", logPath)
	var stdout, stderr bytes.Buffer

	err := runWithIO([]string{"version"}, &stdout, &stderr)

	if err != nil {
		t.Fatalf("runWithIO(version) error = %v", err)
	}
	if got, want := stdout.String(), "orgm-hypr dev\n"; got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
	if got := stderr.String(); got != "" {
		t.Fatalf("stderr = %q, want empty", got)
	}
	if _, err := os.Stat(logPath); !os.IsNotExist(err) {
		t.Fatalf("git log stat error = %v, want git not called", err)
	}
	if got := readFile(t, dotfilesConfig); got != dotfilesBefore {
		t.Fatalf("dotfiles.json = %q, want unchanged %q", got, dotfilesBefore)
	}
	if got := readFile(t, themeRegistry); got != themeBefore {
		t.Fatalf("themes.json = %q, want unchanged %q", got, themeBefore)
	}
	if got := readFile(t, filepath.Join(dotfilesDir, "sentinel.txt")); got != "keep-dotfiles-dir" {
		t.Fatalf("sentinel = %q, want preserved", got)
	}
}

func TestOrgmHyprBootstrapReportsGitFailureWithoutCreatingConfig(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	bin := filepath.Join(root, "bin")
	writeExecutable(t, filepath.Join(bin, "git"), "#!/bin/sh\necho 'network down from fake git' >&2\nexit 42\n")
	t.Setenv("HOME", home)
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	var stdout, stderr bytes.Buffer

	err := runWithIO([]string{"version"}, &stdout, &stderr)

	if err == nil {
		t.Fatalf("runWithIO(version) error = nil, want clone failure")
	}
	target := filepath.Join(home, "Hobby", "dotfiles")
	message := err.Error()
	for _, want := range []string{expectedDotfilesRepoURL, target, "network down from fake git"} {
		if !strings.Contains(message, want) {
			t.Fatalf("error = %q, want substring %q", message, want)
		}
	}
	if got := stdout.String(); got != "" {
		t.Fatalf("stdout = %q, want empty", got)
	}
	if got := stderr.String(); got != "" {
		t.Fatalf("stderr = %q, want empty before cli.PrintError", got)
	}
	if _, err := os.Stat(filepath.Join(target, "config", "dotfiles.json")); !os.IsNotExist(err) {
		t.Fatalf("dotfiles.json stat error = %v, want not exist", err)
	}
	if _, err := os.Stat(filepath.Join(home, ".config", "orgm-hypr", "themes.json")); !os.IsNotExist(err) {
		t.Fatalf("themes.json stat error = %v, want not exist", err)
	}
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
go test ./cmd/orgm-hypr -run 'TestOrgmHyprBootstrap' -count=1
```

Expected output includes failure because bootstrap is not wired yet:

```text
--- FAIL: TestOrgmHyprBootstrapClonesMissingDotfilesBeforeCommand
    dotfiles_bootstrap_test.go:...: dotfiles target stat error = stat .../home/Hobby/dotfiles: no such file or directory, want created
--- FAIL: TestOrgmHyprBootstrapReportsGitFailureWithoutCreatingConfig
    dotfiles_bootstrap_test.go:...: runWithIO(version) error = nil, want clone failure
FAIL
FAIL	github.com/osmargm1202/nixos/cmd/orgm-hypr	...
```

- [ ] **Step 3: Commit failing tests**

```bash
git add cmd/orgm-hypr/dotfiles_bootstrap_test.go
git commit -m "test: cover orgm-hypr dotfiles bootstrap"
```

Expected output:

```text
[master ...] test: cover orgm-hypr dotfiles bootstrap
 1 file changed, ... insertions(+)
 create mode 100644 cmd/orgm-hypr/dotfiles_bootstrap_test.go
```

---

### Task 2: Implement bootstrap helper and startup call

**Files:**
- Create: `cmd/orgm-hypr/dotfiles_bootstrap.go`
- Modify: `cmd/orgm-hypr/main.go:41-47`
- Test: `cmd/orgm-hypr/dotfiles_bootstrap_test.go`

- [ ] **Step 1: Add bootstrap helper**

Create `cmd/orgm-hypr/dotfiles_bootstrap.go` with this complete content:

```go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const orgmDotfilesRepoURL = "https://github.com/osmargm1202/dotfiles"

func bootstrapOrgmDotfiles() error {
	home := os.Getenv("HOME")
	if home == "" {
		return fmt.Errorf("HOME is not set; cannot bootstrap dotfiles repository %s", orgmDotfilesRepoURL)
	}
	target := filepath.Join(home, "Hobby", "dotfiles")
	if _, err := os.Stat(target); err == nil {
		return nil
	} else if !os.IsNotExist(err) {
		return fmt.Errorf("check dotfiles target %s: %w", target, err)
	}
	parent := filepath.Dir(target)
	if err := os.MkdirAll(parent, 0o700); err != nil {
		return fmt.Errorf("create dotfiles parent %s: %w", parent, err)
	}
	cmd := exec.Command("git", "clone", orgmDotfilesRepoURL, target)
	output, err := cmd.CombinedOutput()
	if err != nil {
		detail := strings.TrimSpace(string(output))
		if detail == "" {
			return fmt.Errorf("clone dotfiles repository %s into %s: %w", orgmDotfilesRepoURL, target, err)
		}
		return fmt.Errorf("clone dotfiles repository %s into %s: %w: %s", orgmDotfilesRepoURL, target, err, detail)
	}
	return nil
}
```

- [ ] **Step 2: Wire bootstrap into command startup**

In `cmd/orgm-hypr/main.go`, replace the beginning of `runWithIO`:

```go
func runWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 {
		return cli.UsageError(usage())
	}

	switch args[0] {
```

with:

```go
func runWithIO(args []string, stdout, stderr io.Writer) error {
	if len(args) < 1 {
		return cli.UsageError(usage())
	}
	if err := bootstrapOrgmDotfiles(); err != nil {
		return err
	}

	switch args[0] {
```

- [ ] **Step 3: Run focused tests to verify pass**

Run:

```bash
go test ./cmd/orgm-hypr -run 'TestOrgmHyprBootstrap' -count=1
```

Expected output:

```text
ok  	github.com/osmargm1202/nixos/cmd/orgm-hypr	...
```

- [ ] **Step 4: Run existing `version` and missing-command tests**

Run:

```bash
go test ./cmd/orgm-hypr -run 'TestRunWithIO(VersionWritesCurrentDevVersion|ReportsUsageForMissingCommand)$' -count=1
```

Expected output:

```text
ok  	github.com/osmargm1202/nixos/cmd/orgm-hypr	...
```

This confirms missing command still returns usage without bootstrap and `version` still works after bootstrap succeeds or skips.

- [ ] **Step 5: Commit implementation**

```bash
git add cmd/orgm-hypr/dotfiles_bootstrap.go cmd/orgm-hypr/main.go
git commit -m "feat: bootstrap orgm-hypr dotfiles checkout"
```

Expected output:

```text
[master ...] feat: bootstrap orgm-hypr dotfiles checkout
 2 files changed, ... insertions(+)
 create mode 100644 cmd/orgm-hypr/dotfiles_bootstrap.go
```

---

### Task 3: Run full verification and smoke tests

**Files:**
- Test: all Go tests under `./...`
- Test: `tests/orgm-hypr.bats.sh`

- [ ] **Step 1: Run all Go tests**

Run:

```bash
go test ./... 
```

Expected output includes all packages passing, with lines like:

```text
ok  	github.com/osmargm1202/nixos/cmd/orgm-hypr	...
ok  	github.com/osmargm1202/nixos/internal/theme	...
```

Packages without tests may appear as:

```text
?   	github.com/osmargm1202/nixos/<package>	[no test files]
```

- [ ] **Step 2: Run orgm-hypr smoke test**

Run:

```bash
bash tests/orgm-hypr.bats.sh
```

Expected output:

```text
orgm-hypr smoke tests passed
```

If this smoke test fails because `HOME="$tmp" "$BIN" version` now bootstraps dotfiles and fake `git` is not present in `PATH`, update the smoke test in a separate execution step by creating a fake `git` in `$TMP_BIN_DIR` before the first `version` call. Use this exact script fragment near the existing `go build` line:

```bash
cat >"$TMP_BIN_DIR/git" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [ "$1" = "clone" ]; then
	mkdir -p "$3"
	exit 0
fi
echo "unexpected git args: $*" >&2
exit 99
SH
chmod +x "$TMP_BIN_DIR/git"
```

Then change the first version command from:

```bash
version="$($BIN version)"
```

to:

```bash
version="$(PATH="$TMP_BIN_DIR:$PATH" HOME="$(mktemp -d)" "$BIN" version)"
```

Run again:

```bash
bash tests/orgm-hypr.bats.sh
```

Expected output:

```text
orgm-hypr smoke tests passed
```

- [ ] **Step 3: Commit smoke-test adjustment only if Step 2 required it**

If `tests/orgm-hypr.bats.sh` was modified, run:

```bash
git add tests/orgm-hypr.bats.sh
git commit -m "test: adapt orgm-hypr smoke test for bootstrap"
```

Expected output:

```text
[master ...] test: adapt orgm-hypr smoke test for bootstrap
 1 file changed, ... insertions(+), ... deletions(-)
```

If `tests/orgm-hypr.bats.sh` passed without modification, do not create this commit.

---

## Final Verification Checklist

- [ ] `go test ./cmd/orgm-hypr -run 'TestOrgmHyprBootstrap' -count=1` passes.
- [ ] `go test ./...` passes.
- [ ] `bash tests/orgm-hypr.bats.sh` passes.
- [ ] `git diff --name-only HEAD~3..HEAD` or commit range equivalent contains only files listed in this plan.
- [ ] No task edits `internal/dotconfig`, `config/dotfiles.json`, theme registry data, generated theme outputs, or JSON schema files.
- [ ] Existing `~/Hobby/dotfiles` is never overwritten, removed, pulled, reset, or validated.
- [ ] Clone failure error includes `https://github.com/osmargm1202/dotfiles` and `$HOME/Hobby/dotfiles`.

## Commit Plan

1. `test: cover orgm-hypr dotfiles bootstrap`
2. `feat: bootstrap orgm-hypr dotfiles checkout`
3. `test: adapt orgm-hypr smoke test for bootstrap` only if smoke test needs fake git isolation.

## Self-Review

- **Spec coverage:**
  - Auto-clone missing `~/Hobby/dotfiles`: Task 1 test `TestOrgmHyprBootstrapClonesMissingDotfilesBeforeCommand`, Task 2 helper and startup call.
  - Skip existing directory: Task 1 test `TestOrgmHyprBootstrapSkipsExistingDotfilesAndPreservesConfig`, Task 2 `os.Stat(target)` early return.
  - No `dotfiles.json` overwrite: Task 1 byte-for-byte `dotfilesConfig` assertion, Task 2 helper never opens that path.
  - No theme overwrite: Task 1 byte-for-byte `themeRegistry` assertion, Task 2 helper never opens theme paths.
  - Git failure clear error and non-zero command result: Task 1 failure test checks URL, target path, fake git message; Task 2 returns non-nil error before command dispatch.
  - No JSON-configurable URL: Task 2 hardcoded `orgmDotfilesRepoURL` constant.
- **Placeholder scan:** Plan contains concrete files, code, commands, expected output, and commits. No deferred implementation markers are used.
- **Type consistency:** Tests and implementation consistently use `bootstrapOrgmDotfiles`, `orgmDotfilesRepoURL`, `expectedDotfilesRepoURL`, `runWithIO`, and `filepath.Join(home, "Hobby", "dotfiles")`.
