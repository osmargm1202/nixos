"""Group Envy's retained systemd-boot entries by newest generation, then mode."""
import os
from pathlib import Path
import re
import stat
import sys
import tempfile


ENTRY = re.compile(r'nixos-generation-([0-9]+)(?:-specialisation-([\w.-]+))?'
                   r'(?:\+[0-9]+(?:-[0-9]+)?)?\.conf', re.ASCII)
MODES = {'normal': 0, 'windows-vfio': 1, 'gaming': 2, 'server': 3}


def order_entries(directory):
    entries = []
    for path in Path(directory).iterdir():
        match = ENTRY.fullmatch(path.name)
        if match and path.is_file() and not path.is_symlink():
            entries.append((path, int(match[1]), match[2] or 'normal'))
    generations = sorted({generation for _, generation, _ in entries}, reverse=True)
    ranks = {generation: rank for rank, generation in enumerate(generations)}
    for path, generation, mode in entries:
        # sort-key sorts A-Z before version. Generation rank must precede mode.
        key = f'nixos-{ranks[generation]:08d}-{MODES.get(mode, 99):02d}-{mode}'
        original = path.read_text()
        updated, count = re.subn(r'^sort-key[ \t]+[^\n]*', 'sort-key ' + key,
                                 original, flags=re.MULTILINE)
        if not count:
            updated = 'sort-key ' + key + '\n' + original
        if updated == original:
            continue
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(mode='w', dir=path.parent,
                                             prefix='.nixos-order-', delete=False) as output:
                temporary = Path(output.name)
                output.write(updated)
                output.flush()
                os.fsync(output.fileno())
            temporary.chmod(stat.S_IMODE(path.stat().st_mode))
            os.replace(temporary, path)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)


if __name__ == '__main__':
    order_entries(sys.argv[1])
