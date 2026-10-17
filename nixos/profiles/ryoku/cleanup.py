"""Retire known desktop artifacts without deleting accounts or application data."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile


def safe_target(home, relative):
    target = home / relative
    if target == home or ".." in Path(relative).parts or Path(relative).is_absolute():
        raise ValueError("invalid cleanup target: " + relative)
    parent = target.parent
    while parent != home:
        if parent.is_symlink():
            return None
        parent = parent.parent
    return target


def archive(target, relative, state):
    try:
        contents = target.read_bytes()
    except FileNotFoundError:
        if not target.is_symlink():
            return
        contents = ("Previous link: " + os.readlink(target) + "\n").encode()
    backup = state / "desktop-cleanup-v1" / relative
    backup.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    if backup.exists():
        if backup.read_bytes() == contents:
            return
        backup = backup.with_name(backup.name + "." + hashlib.sha256(contents).hexdigest()[:12])
    if not backup.exists():
        backup.write_bytes(contents)
        backup.chmod(0o600)


def mask_text(name):
    return "[Desktop Entry]\nType=Application\nName=" + name + "\nHidden=true\n"


def cleanup(home, state, manifest, apply_masks=False, keep_units=False):
    for row in manifest.get("files", []):
        target = safe_target(home, row["target"])
        if target is None or not target.is_file():
            continue
        if any(target.read_bytes() == Path(source).read_bytes() for source in row["sources"]):
            archive(target, row["target"], state)
            target.unlink()
            print("Ryoku: retired " + row["target"])
    if not keep_units:
        for relative in manifest.get("packageUnits", []):
            target = safe_target(home, relative)
            if target is None or not target.is_symlink():
                continue
            resolved = str(target.resolve())
            if (resolved.startswith("/nix/store/") and "-syncthing-" in resolved
                    and resolved.endswith("/share/systemd/user/syncthing.service")):
                archive(target, relative, state)
                target.unlink()
                print("Ryoku: retired package-pinned unit " + relative)
    for name in manifest.get("autostart", []):
        relative = ".config/autostart/" + name
        target = safe_target(home, relative)
        if target is None:
            continue
        text = mask_text(name)
        existing = target.read_text() if target.exists() else None
        if existing is not None and existing != text:
            archive(target, relative, state)
        if apply_masks and (existing != text or target.is_symlink()):
            target.parent.mkdir(parents=True, exist_ok=True)
            fd, tmp = tempfile.mkstemp(prefix=target.name + ".", dir=target.parent)
            try:
                with os.fdopen(fd, "w") as out:
                    out.write(text)
                os.replace(tmp, target)
            finally:
                if os.path.exists(tmp):
                    os.unlink(tmp)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("home", type=Path)
    parser.add_argument("state", type=Path)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--apply-masks", action="store_true")
    parser.add_argument("--keep-units", action="store_true")
    args = parser.parse_args()
    cleanup(args.home, args.state, json.loads(args.manifest.read_text()), args.apply_masks, args.keep_units)
