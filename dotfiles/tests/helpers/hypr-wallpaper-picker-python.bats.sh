#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT/config/shared/.config/hypr/wallpaper-picker"
APP="$APP_DIR/wallpaper_picker.py"

compile_tmp="$(mktemp)"
python - <<'PY' "$APP" "$compile_tmp"
import py_compile
import sys
py_compile.compile(sys.argv[1], cfile=sys.argv[2], doraise=True)
PY
rm -f "$compile_tmp"

PYTHONDONTWRITEBYTECODE=1 python -B - <<'PY' "$APP_DIR"
import json
import pathlib
import sys
import tempfile

sys.path.insert(0, sys.argv[1])
import wallpaper_picker as wp

with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp)
    image = root / "static" / "mountain.jpg"
    thumb = image.parent / ".thumb" / "mountain.jpg.png"
    thumb.parent.mkdir(parents=True)
    image.write_text("image")
    thumb.write_text("thumb")

    found = wp.scan_wallpapers(image.parent)
    assert found == [wp.WallpaperItem(path=str(image), name="mountain.jpg", thumb=str(thumb))]

    payload = {
        "tabs": {
            "static": {"items": [{"path": str(image), "name": "Pretty", "thumb": str(thumb)}]},
            "video": {"items": [{"file": str(root / "clip.mp4"), "thumbnail": str(root / "clip.png")}]}},
        "monitors": [{"name": "DP-1", "description": "Main"}, "HDMI-A-1"],
    }
    data = wp.load_picker_json_from_payload(payload)
    assert data.tabs["static"][0].name == "Pretty"
    assert data.tabs["video"][0].path.endswith("clip.mp4")
    assert data.tabs["video"][0].thumb.endswith("clip.png")
    assert [m.output for m in data.monitors] == ["DP-1", "HDMI-A-1"]

    assert wp.build_backend_command("set-static", str(image), "DP-1") == ["orgm-wallpaper", "set-static", str(image), "--monitor", "DP-1"]
    assert wp.build_backend_command("random-video", None, None) == ["orgm-wallpaper", "random-video"]

print("hypr wallpaper picker python smoke test passed")
PY

for launcher in \
    "$ROOT/config/shared/.local/bin/hypr-wallpaper-picker" \
    "$ROOT/config/shared/.local/bin/hypr-wallpaper-picker-dark" \
    "$ROOT/config/shared/.local/bin/hypr-wallpaper-picker-light"; do
    bash -n "$launcher"
done

with_fake_home() {
    local tmp="$1"
    mkdir -p "$tmp/home/.config/hypr/wallpaper-picker" "$tmp/home/.local/bin" "$tmp/bin"
    cp "$APP" "$tmp/home/.config/hypr/wallpaper-picker/wallpaper_picker.py"
    cp "$ROOT/config/shared/.local/bin/hypr-wallpaper-picker" "$tmp/home/.local/bin/"
    cp "$ROOT/config/shared/.local/bin/hypr-wallpaper-picker-dark" "$tmp/home/.local/bin/"
    cp "$ROOT/config/shared/.local/bin/hypr-wallpaper-picker-light" "$tmp/home/.local/bin/"
}

success_tmp="$(mktemp -d)"
trap 'rm -rf "$success_tmp" "$fallback_tmp"' EXIT
with_fake_home "$success_tmp"
cat >"$success_tmp/bin/python3" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-c" ]]; then
    exit 0
fi
printf '%s\n' "$@" >"$TEST_RECORD"
SH
chmod +x "$success_tmp/bin/python3"
TEST_RECORD="$success_tmp/record" HOME="$success_tmp/home" PATH="$success_tmp/bin:$PATH" \
    "$success_tmp/home/.local/bin/hypr-wallpaper-picker-dark" --page-size 9 "arg with spaces"
grep -Fx -- "$success_tmp/home/.config/hypr/wallpaper-picker/wallpaper_picker.py" "$success_tmp/record" >/dev/null
grep -Fx -- "--theme" "$success_tmp/record" >/dev/null
grep -Fx -- "dark" "$success_tmp/record" >/dev/null
grep -Fx -- "arg with spaces" "$success_tmp/record" >/dev/null

fallback_tmp="$(mktemp -d)"
with_fake_home "$fallback_tmp"
cat >"$fallback_tmp/bin/python3" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-c" ]]; then
    exit 1
fi
printf 'unexpected direct python execution\n' >&2
exit 42
SH
cat >"$fallback_tmp/bin/nix-shell" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"$TEST_RECORD"
SH
chmod +x "$fallback_tmp/bin/python3" "$fallback_tmp/bin/nix-shell"
TEST_RECORD="$fallback_tmp/record" HOME="$fallback_tmp/home" PATH="$fallback_tmp/bin:$PATH" \
    "$fallback_tmp/home/.local/bin/hypr-wallpaper-picker-light" --monitor "DP 1"
grep -Fx -- "python3.withPackages (ps: [ ps.pygobject3 ])" "$fallback_tmp/record" >/dev/null
grep -Fx -- "gtk4" "$fallback_tmp/record" >/dev/null
grep -Fx -- "gobject-introspection" "$fallback_tmp/record" >/dev/null
grep -F -- "--theme light" "$fallback_tmp/record" >/dev/null
grep -F -- "--monitor" "$fallback_tmp/record" >/dev/null
