"""Build-time guard for the pinned Lenovo image, never run against personal data."""
from pathlib import Path
import sys

NEEDLE = "  if needsInstall; then\n\n    startInstall || exit $?"
REPLACEMENT = '''  if needsInstall; then
    error "windows-vm: installation/reinstallation is disabled for this Lenovo image; review the existing disk and state manually."
    exit 78

    startInstall || exit $?'''


def patch_install(path):
    source = path.read_text()
    if source.count(NEEDLE) != 1:
        raise RuntimeError("pinned Windows installer guard does not match; refusing to build")
    path.write_text(source.replace(NEEDLE, REPLACEMENT))


if __name__ == "__main__":
    patch_install(Path(sys.argv[1]) if len(sys.argv) == 2 else Path("/run/install.sh"))
