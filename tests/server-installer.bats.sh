#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$REPO_DIR" <<'PY'
import os
import pathlib
import subprocess
import sys
import tempfile
import tomllib

repo = pathlib.Path(sys.argv[1])
bash = subprocess.check_output(["which", "bash"], text=True).strip()
installer = repo / "server/install.sh"

def snapshot(home):
    return sorted((str(p.relative_to(home)), p.is_symlink(),
                   os.readlink(p) if p.is_symlink() else p.read_bytes())
                  for p in home.rglob("*") if p.is_file() or p.is_symlink())

def install(home, *args, source=repo, success=True):
    result = subprocess.run([bash, str(installer), "--source", str(source),
                             "--home", str(home), "--no-plugins", *args],
                            capture_output=True, text=True, timeout=30)
    assert (result.returncode == 0) == success, result.stdout + result.stderr
    return result

with tempfile.TemporaryDirectory(prefix="orgm-installer-") as root:
    root = pathlib.Path(root)
    home = root / "home"
    home.mkdir()
    original = root / "original-bashrc"
    original.write_text('export HOST_PRIVATE_SETTING="preserved"\n')
    (home / ".bashrc").symlink_to(original)
    profile = home / ".bash_profile"
    profile.write_text('export HOST_PROFILE_SETTING="preserved"\n')
    before = snapshot(home)

    install(home, "--dry-run")
    assert snapshot(home) == before, "dry-run must not write dotfiles or backups"
    missing = root / "missing-source"
    missing.mkdir()
    install(home, source=missing, success=False)
    assert snapshot(home) == before, "failed staging must not modify existing configuration"

    install(home)
    assert original.read_text() == 'export HOST_PRIVATE_SETTING="preserved"\n', "symlink target must not be overwritten"
    assert not (home / ".bashrc").is_symlink(), "managed Bash should replace the link, not edit its target"
    assert any(p.is_symlink() and p.resolve() == original for p in home.rglob("*")), "backup must preserve original symlink"
    assert 'HOST_PROFILE_SETTING="preserved"' in profile.read_text(), "login profile customization must survive"
    for helper in ('bun-install', 'blesh-install', 'codex-install', 'codex-update',
                   'claude-install', 'claude-update', 'omp-install', 'omp-update',
                   'switch-preview', 'dir-preview'):
        assert os.access(home / '.local/bin' / helper, os.X_OK), f'{helper} must be executable'
    assert (home / '.blerc').is_file(), 'Emacs editing and completion settings must be installed'
    prompt = tomllib.loads((home / '.config/starship.toml').read_text())
    assert prompt['scan_timeout'] == 200 and prompt['command_timeout'] == 1000, prompt
    assert prompt['netns']['disabled'], 'SSH prompts must not query unused network namespaces'
    assert prompt['palette'] in prompt['palettes'], 'installed prompt must retain its color palette'

    env = os.environ.copy()
    env.update(HOME=str(home), TERM="dumb")
    # Explicitly source the login profile: bash -l can substitute HOME via /etc/profile.
    result = subprocess.run([bash, "--noprofile", "--norc", "-ic",
                             'source "$HOME/.bash_profile"; printf "%s:%s" "$HOST_PROFILE_SETTING" "$HISTSIZE"'],
                            env=env, capture_output=True, text=True, timeout=10)
    assert result.returncode == 0 and result.stdout == "preserved:10000", result.stdout + result.stderr

    installed = snapshot(home)
    install(home)
    assert snapshot(home) == installed, "identical reinstall must not create more backups or alter configuration"

    tmux_home = root / "tmux-only"
    tmux_home.mkdir()
    (tmux_home / ".bashrc").write_text("# untouched Bash\n")
    install(tmux_home, "--tmux-only")
    assert (tmux_home / ".bashrc").read_text() == "# untouched Bash\n", "tmux-only must preserve Bash"
    assert not (tmux_home / ".bash_profile").exists(), "tmux-only must not alter login profiles"
    assert not (tmux_home / '.config/bash').exists(), 'tmux-only must not install Bash modules'
    assert not (tmux_home / '.local/bin/codex-install').exists(), 'tmux-only must not install AI helpers'

    protected_home = root / 'protected'
    protected_home.mkdir()
    (protected_home / '.blerc').symlink_to('/nix/store/orgm-protected-blerc')
    before = snapshot(protected_home)
    install(protected_home, success=False)
    assert snapshot(protected_home) == before, 'all new destinations must be checked before modifying HOME'
print("PASS: installer dry-run, failed staging, symlink backup, login customization, idempotence and tmux-only")
PY
