#!/usr/bin/env python3
"""Build a complete, pinned qylock catalog and small static carousel previews."""
import configparser
import json
from pathlib import Path
import subprocess
import sys

source, destination = map(Path, sys.argv[1:])
(destination/'previews').mkdir(parents=True, exist_ok=True)
aliases = {'Genshin': 'genshin', 'last-of-us': 'the_last_of_us', 'windows_7': 'win7'}
items = []
for main in sorted((source/'themes').rglob('Main.qml')):
    slug = main.parent.relative_to(source/'themes').as_posix()
    choices = [slug, aliases.get(slug, ''), slug.replace('-', '_'), slug.replace('_', '-'), slug.lower()]
    if slug.startswith('clockwork/'):
        choices = ['clockwork']
    preview = next((source/'Assets'/f'{name}.gif' for name in choices if name and (source/'Assets'/f'{name}.gif').is_file()), None)
    if preview is None:
        preview = next((p for p in main.parent.glob('*') if p.suffix.lower() in ('.png', '.jpg', '.mp4', '.webm')), None)
    if preview is None:
        raise RuntimeError(f'No preview asset for {slug}')
    filename = slug.replace('/', '--') + '.png'
    subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', '-i', str(preview),
                    '-frames:v', '1', '-vf', 'scale=960:600:force_original_aspect_ratio=decrease',
                    '-threads', '1', str(destination/'previews'/filename)], check=True)
    settings = configparser.ConfigParser(interpolation=None, strict=False)
    settings.optionxform = str
    settings.read(main.parent/'theme.conf')
    config = dict(settings['General']) if settings.has_section('General') else {}
    items.append(dict(id=slug, name=slug.replace('/', ' · ').replace('-', ' ').replace('_', ' ').title(),
                      config=config, preview=filename))
(destination/'catalog.json').write_text(json.dumps(items, ensure_ascii=False, indent=2)+'\n')
print(f'Prepared {len(items)} qylock themes')
