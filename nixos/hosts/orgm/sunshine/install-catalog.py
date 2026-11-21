"""Deploy the versioned catalog while preserving edits made in Sunshine."""

import json
from pathlib import Path
import sys
import tempfile


def read(path):
    try:
        return path.read_bytes()
    except FileNotFoundError:
        return None


def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as output:
        temporary = Path(output.name)
        try:
            output.write(content)
            output.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def equivalent_json(first, second):
    if first is None or second is None:
        return first == second
    try:
        return json.loads(first) == json.loads(second)
    except ValueError:
        return False


def deploy(path, wanted, previous, equivalent=lambda a, b: a == b):
    live = read(path)
    if not equivalent(live, wanted):
        if live is not None and not equivalent(live, read(previous)):
            print(f"Sunshine: se conservó la edición local de {path}; revisar contra Git.", file=sys.stderr)
            return
        write(path, wanted)
    if read(previous) != wanted:
        write(previous, wanted)


def main():
    source, home, config, state = map(Path, sys.argv[1:])
    raw = (source / "apps.json").read_text()
    home_value = json.dumps(str(home), ensure_ascii=False)[1:-1]
    config_value = json.dumps(str(config), ensure_ascii=False)[1:-1]
    catalog = raw.replace("@home@", home_value).replace("@config@", config_value).encode()
    for asset in (source / "session").iterdir():
        if asset.is_file():
            deploy(config / "sunshine/session" / asset.name, asset.read_bytes(),
                   state / "session" / asset.name)
    for app in json.loads(catalog)["apps"]:
        image = Path(app.get("image-path") or "")
        if image.is_absolute():
            asset = source / "covers" / image.name
            deploy(image, asset.read_bytes(), state / "covers" / image.name)
    deploy(config / "sunshine/apps.json", catalog, state / "apps.json", equivalent_json)


if __name__ == "__main__":
    main()
