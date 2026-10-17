"""Initial personal preferences, not a convergence loop over user-owned files."""
import fcntl
import hashlib
import json
import os
import shutil
from pathlib import Path, PurePosixPath
import sys
import tempfile


def store_suffix(path):
    """Only our explicitly named dotfile source can match an older generation."""
    text = str(path)
    if not text.startswith("/nix/store/"):
        return None
    parts = text[len("/nix/store/"):].split("/", 1)
    if len(parts) != 2 or not parts[0].endswith("-user-dotfiles"):
        return None
    return parts[1]


def known_legacy(target, sources, directory=False):
    present = target.is_dir() if directory else target.is_file()
    if not target.is_symlink() or not present:
        return False
    actual = target.resolve()
    for source in sources:
        expected = Path(source).resolve()
        if actual == expected:
            return True
        suffix = store_suffix(expected)
        if suffix is not None and store_suffix(actual) == suffix:
            return True
    return False


def safe_parent(root, target):
    """Never follow a user's directory symlink while populating children."""
    current = root
    for part in target.parent.relative_to(root).parts:
        if current.is_symlink():
            return False
        current = current / part
        if current.is_symlink():
            return False
        if current.exists() and not current.is_dir():
            return False
    if root.is_symlink():
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    return True


def atomic_file(path, data, mode, replace=False):
    fd, name = tempfile.mkstemp(prefix=".ryoku-seed-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(data)
        os.chmod(name, mode)
        if replace:
            os.replace(name, path)  # Replace link itself; never open its target.
        else:
            try:
                os.link(name, path)  # Atomic create-if-absent, including symlinks.
            except FileExistsError:
                pass
    finally:
        if os.path.exists(name):
            os.unlink(name)


def previous_preference(state, relative):
    """Restore a prior Ryoku choice only during entry from another boot mode."""
    pointer = state / "return-latest"
    if (state / "active").exists() or pointer.is_symlink() or not pointer.is_file():
        return None
    root = Path(pointer.read_text().strip())
    if root.parent != state or not root.name.startswith("return-") or root.is_symlink():
        return None
    source = root / relative
    current = source
    while current != root:
        if current.is_symlink():
            return None
        current = current.parent
    if not source.is_file():
        return None
    replacements = root / "replacement-sources.json"
    expected = []
    if replacements.is_file() and not replacements.is_symlink():
        value = json.loads(replacements.read_text()).get(relative)
        if isinstance(value, str):
            expected.append(value)
    return source, expected


def seed(config, state, home, records):
    prepared = []
    for row in records:
        relative = PurePosixPath(row["target"])
        if relative.is_absolute() or ".." in relative.parts or not relative.parts:
            raise ValueError("unsafe seed target: " + str(relative))
        root = config if relative.parts[0] == ".config" else home
        parts = relative.parts[1:] if relative.parts[0] == ".config" else relative.parts
        if not parts:
            raise ValueError("seed target must name a file")
        source = Path(row["source"])
        if not source.is_file():
            raise ValueError("missing seed source for " + str(relative))
        prepared.append((row, root, root.joinpath(*parts)))
    state.mkdir(parents=True, exist_ok=True)
    with (state / ".seed.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for row, root, target in prepared:
            if not safe_parent(root, target):
                print("Ryoku: preserved directory link for " + row["target"], file=sys.stderr)
                continue
            exists = os.path.lexists(target)
            previous = previous_preference(state, row["target"])
            if previous is not None:
                saved, replacements = previous
                if not exists or known_legacy(target, row.get("legacySources", []) + replacements):
                    atomic_file(target, saved.read_bytes(), saved.stat().st_mode & 0o777, replace=exists)
                    continue
            key = hashlib.sha256(row["target"].encode()).hexdigest()
            backup_dir = state / "seeds-v1"
            metadata = backup_dir / (key + ".metadata.json")
            if exists and not metadata.exists() and known_legacy(target, row.get("legacySources", [])):
                if backup_dir.is_symlink():
                    raise ValueError("seed backup directory must not be a symlink")
                backup_dir.mkdir(mode=0o700, exist_ok=True)
                backup_dir.chmod(0o700)
                original = target.read_bytes()
                info = {"target": row["target"], "link": os.readlink(target),
                        "resolved": str(target.resolve()), "sha256": hashlib.sha256(original).hexdigest()}
                atomic_file(backup_dir / (key + ".before"), original, 0o600)
                content = Path(row["source"]).read_bytes() if row.get("replaceLegacy", False) else original
                atomic_file(target, content, 0o644, replace=True)
                # Completion follows replacement, so a failed rename is retryable.
                atomic_file(metadata, (json.dumps(info, indent=2) + "\n").encode(), 0o600)
            elif not exists and row.get("seed", True):
                atomic_file(target, Path(row["source"]).read_bytes(), 0o644)
            elif row["target"] == ".bashrc":
                if not target.is_file() or b"ryoku.bash" not in target.read_bytes():
                    print("Ryoku: preserved personal .bashrc; import ~/.config/bash/ryoku.bash to use native startup", file=sys.stderr)


def migrate_directories(home, state, records):
    """Withdraw only a registered old directory link; preserve full provenance."""
    state.mkdir(parents=True, exist_ok=True)
    with (state / ".seed.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for row in records:
            relative = PurePosixPath(row["target"])
            if relative.is_absolute() or ".." in relative.parts or not relative.parts:
                raise ValueError("unsafe legacy directory: " + str(relative))
            target = home / str(relative)
            if not target.is_symlink():
                continue
            if not safe_parent(home, target):
                if row["blocksNative"]:
                    raise ValueError("Ryoku: preserved personal directory link above " + str(relative)
                                     + "; use a writable directory before materializing")
                continue
            actual = target.resolve()
            parts = str(actual).removeprefix("/nix/store/").split("/", 1)
            hm_owned = (str(actual).startswith("/nix/store/") and len(parts) == 2
                        and parts[0].endswith("-home-manager-files") and parts[1] == str(relative))
            known = known_legacy(target, row["sources"], directory=True) or hm_owned
            backup = state / "legacy-directories-v1" / str(relative)
            metadata = backup.with_name(backup.name + ".metadata.json")
            if not known or metadata.exists():
                if row["blocksNative"]:
                    raise ValueError("Ryoku: preserved personal directory link " + str(relative)
                                     + "; use a writable directory before materializing")
                continue
            # Do not follow a link in our backup parents either.
            if not safe_parent(state, backup) or backup.exists() or backup.is_symlink():
                raise ValueError("preserved legacy directory; inspect existing backup: " + str(backup))
            backup.parent.chmod(0o700)
            shutil.copytree(target, backup, copy_function=shutil.copyfile)
            backup.chmod(0o700)
            info = {"target": str(relative), "link": os.readlink(target), "resolved": str(actual)}
            atomic_file(metadata, (json.dumps(info, indent=2) + "\n").encode(), 0o600)
            target.unlink()  # Bytes and link provenance already safely backed up.


if __name__ == "__main__":
    if sys.argv[1] == "--directories":
        home, state, manifest = map(Path, sys.argv[2:])
        migrate_directories(home, state, json.loads(manifest.read_text()))
    else:
        config, state, home, manifest = map(Path, sys.argv[1:])
        seed(config, state, home, json.loads(manifest.read_text()))
