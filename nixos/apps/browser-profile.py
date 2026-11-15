"""Set requested Origin preferences only while its profile is closed."""
import json
import os
from pathlib import Path
import shutil
import tempfile

root = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config')))/'BraveSoftware/Brave-Origin'
if (root/'SingletonLock').is_symlink():
    print('Origin is running; profile preferences will be configured at the next activation with Origin closed.')
    raise SystemExit(0)
for relative, settings in {
    'Local State': [('brave', 'origin', 'free_tier_accepted'), ('brave', 'widevine_opted_in')],
    'Default/Preferences': [('brave', 'tabs', 'vertical_tabs_enabled')],
}.items():
    target = root/relative
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    exists = target.exists()
    data = json.loads(target.read_text()) if exists else {}
    changed = False
    for keys in settings:
        section = data
        for key in keys[:-1]:
            section = section.setdefault(key, {})
        if section.get(keys[-1]) is not True:
            section[keys[-1]] = True
            changed = True
    if not changed:
        continue
    if exists:
        backup = root/'.orgm-before-origin'/relative
        backup.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        if not backup.exists():
            shutil.copy2(target, backup)
            backup.chmod(0o600)
    descriptor, temporary = tempfile.mkstemp(dir=target.parent, prefix='.orgm-origin-')
    try:
        with os.fdopen(descriptor, 'w') as output:
            json.dump(data, output)
        os.replace(temporary, target)
    finally:
        Path(temporary).unlink(missing_ok=True)
