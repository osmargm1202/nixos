#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="$ROOT/nixos/packages/windows-manager-linux-orgm/native-host.py"
MANIFEST="$ROOT/nixos/packages/windows-manager-linux-orgm/manifest.json"
PACKAGE="$ROOT/nixos/packages/windows-manager-linux-orgm.nix"
MODULE="$ROOT/nixos/firefox.nix"
SIGNED_XPI="$ROOT/nixos/packages/windows-manager-linux-orgm/windows-manager-linux-orgm-signed.xpi"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

python3 -m json.tool "$MANIFEST" >/dev/null
python3 -m py_compile "$HOST"
node "$ROOT/tests/windows-manager-linux-orgm-background.test.js"
grep -Fq '"manifest_version": 2' "$MANIFEST" || fail 'Firefox extension must keep a persistent background page'
grep -Fq '"strict_min_version": "142.0"' "$MANIFEST" || fail 'Firefox extension must require the first Android version supporting data consent'
grep -Fq '"persistent": true' "$MANIFEST" || fail 'Firefox extension must retain the native bridge connection'
grep -Fq '"nativeMessaging"' "$MANIFEST" || fail 'Firefox extension lacks native messaging permission'
grep -Fq '"data_collection_permissions"' "$MANIFEST" || fail 'Firefox extension must declare its data collection policy'
grep -Fq '"required": ["none"]' "$MANIFEST" || fail 'Firefox extension must declare that it collects no data'
grep -Fq 'nativeMessagingHosts.packages = [ windowsManagerLinuxOrgm ];' "$MODULE" || fail 'browser must expose the native host'
grep -Fq 'windows-manager-linux-orgm-signed.xpi' "$MODULE" || fail 'browser must await the signed XPI before activation'
grep -Fq 'lib/mozilla/native-messaging-hosts/windows_manager_linux_orgm.json' "$PACKAGE" || fail 'package must install the native host manifest'
grep -Fq 'windows-manager-linux-orgm-tabs' "$PACKAGE" || fail 'package must install the tab-list client'
python3 - "$MANIFEST" "$ROOT/nixos/packages/windows-manager-linux-orgm/background.js" "$SIGNED_XPI" <<'PY'
import json
import sys
import zipfile

manifest_path, background_path, signed_xpi_path = sys.argv[1:]
with open(manifest_path, encoding="utf-8") as source:
    source_manifest = json.load(source)
with open(background_path, "rb") as source:
    source_background = source.read()
with zipfile.ZipFile(signed_xpi_path) as archive:
    signed_manifest = json.loads(archive.read("manifest.json"))
    assert signed_manifest == source_manifest, "signed XPI manifest differs from tracked source"
    assert archive.read("background.js") == source_background, "signed XPI background differs from tracked source"
    assert signed_manifest["browser_specific_settings"]["gecko"]["id"] == "windows_manager_linux_orgm@or-gm.com"
    assert signed_manifest["version"] == "1.0.5"
    required_signatures = {
        "META-INF/manifest.mf",
        "META-INF/mozilla.sf",
        "META-INF/mozilla.rsa",
    }
    assert required_signatures.issubset(archive.namelist()), "XPI lacks Mozilla signature metadata"
PY

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
(
	cd "$ROOT"
	nix build --impure --out-link "$tmp/package" --expr 'let pkgs = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux; in pkgs.callPackage ./nixos/packages/windows-manager-linux-orgm.nix { }'
)
mkdir "$tmp/no-socket-runtime"
if XDG_RUNTIME_DIR="$tmp/no-socket-runtime" "$tmp/package/bin/windows-manager-linux-orgm-tab" https://example.com/ 2>"$tmp/wrapper-error"; then
	fail 'wrapper should fail while the native host socket is absent'
fi
grep -Fq 'windows-manager-linux-orgm-tab:' "$tmp/wrapper-error" || fail 'wrapper did not start the packaged native host'
if XDG_RUNTIME_DIR="$tmp/no-socket-runtime" "$tmp/package/bin/windows-manager-linux-orgm-tabs" list 2>"$tmp/tabs-wrapper-error"; then
	fail 'tab-list wrapper should fail while the native host socket is absent'
fi
grep -Fq 'windows-manager-linux-orgm-tabs:' "$tmp/tabs-wrapper-error" || fail 'tab-list wrapper did not report its failure'
python3 - "$HOST" "$tmp" <<'PY'
import base64
import importlib.util
import json
import os
import struct
import subprocess
import socket
import sys
import threading
import time
import urllib.error
import zipfile
import zlib
from pathlib import Path

host_path = sys.argv[1]
runtime_dir = Path(sys.argv[2])
spec = importlib.util.spec_from_file_location("native_host", host_path)
native_host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native_host)
xpi_path = runtime_dir / "package/share/windows-manager-linux-orgm/windows-manager-linux-orgm-unsigned.xpi"
with zipfile.ZipFile(xpi_path) as xpi:
    assert set(xpi.namelist()) == {"manifest.json", "background.js"}
    assert json.loads(xpi.read("manifest.json")) == json.loads(
        Path(host_path).with_name("manifest.json").read_text(encoding="utf-8")
    )
assert native_host.valid_url("https://example.com/path")
assert not native_host.valid_url("about:blank")
socket_path = runtime_dir / "windows_manager_linux_orgm.sock"

def png_fixture(width=1, height=1):
    def chunk(kind, value):
        return struct.pack(">I", len(value)) + kind + value + struct.pack(">I", zlib.crc32(kind + value) & 0xFFFFFFFF)
    raw = b"".join(b"\0" + b"\0\0\0\0" * width for _ in range(height))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


png = png_fixture()

gif = base64.b64decode("R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==")
jpeg = (
    b"\xff\xd8"
    + b"\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00"
    + b"\xff\xd9"
)
webp_payload = b"\x2f\x00\x00\x00\x00"
webp = b"RIFF" + struct.pack("<I", 4 + 8 + len(webp_payload) + 1) + b"WEBPVP8L" + struct.pack("<I", len(webp_payload)) + webp_payload + b"\0"
ico = b"\0\0\1\0\1\0" + b"\1\1\0\0\1\0\32\0" + struct.pack("<II", len(png), 22) + png
for suffix, image in {
    "png": png,
    "jpg": jpeg,
    "gif": gif,
    "webp": webp,
    "ico": ico,
}.items():
    assert native_host.valid_favicon_image(image, suffix), f"valid {suffix} fixture was rejected"
    assert not native_host.valid_favicon_image(image[:12], suffix), f"truncated {suffix} fixture was accepted"
assert not native_host.valid_favicon_image(b"\x89PNG\r\n\x1a\nsignature-only", "png")
assert not native_host.valid_favicon_image(png_fixture(native_host.MAX_FAVICON_DIMENSION + 1, 1), "png")

for url in (
    "https://127.0.0.1/favicon.ico",
    "https://10.0.0.1/favicon.ico",
    "https://169.254.1.1/favicon.ico",
    "https://[::1]/favicon.ico",
    "https://[fc00::1]/favicon.ico",
):
    assert native_host.canonical_favicon_url(url) is None, f"non-global literal accepted: {url}"

global_record = (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("8.8.8.8", 443))
private_record = (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("127.0.0.1", 443))
assert native_host.FaviconCache._resolved_global_address(
    "public.example", 443, lambda *_: [global_record]
) == "8.8.8.8"
try:
    native_host.FaviconCache._resolved_global_address(
        "mixed.example", 443, lambda *_: [global_record, private_record]
    )
    raise AssertionError("hostname with a non-global resolved address was accepted")
except ValueError:
    pass

class FakeSocket:
    def __init__(self):
        self.timeouts = []

    def settimeout(self, timeout):
        self.timeouts.append(timeout)


class FakeResponse:
    status = 200
    headers = {"Content-Type": "image/png", "Content-Length": str(len(png))}

    def __init__(self):
        self.data = bytearray(png)

    def read1(self, size):
        chunk, self.data = self.data[:size], self.data[size:]
        return bytes(chunk)


connections = []
class FakeConnection:
    def __init__(self, host, port, address, timeout):
        self.host, self.port, self.address, self.timeout = host, port, address, timeout
        self.sock = FakeSocket()
        self.request_args = None
        connections.append(self)

    def request(self, method, target, headers):
        self.request_args = (method, target, headers)

    def getresponse(self):
        return FakeResponse()

    def close(self):
        pass


pinned_cache = native_host.FaviconCache(
    cache_dir=runtime_dir / "pinned",
    resolver=lambda *_: [global_record],
    connection_factory=FakeConnection,
)
assert pinned_cache._fetch("https://public.example/favicon.png") == ("image/png", png)
assert connections[0].host == "public.example"
assert connections[0].address == "8.8.8.8"
assert connections[0].request_args[2]["Host"] == "public.example"
pinned_cache.close()

clock = [0.0]
class SlowResponse:
    def read1(self, size):
        clock[0] += native_host.FAVICON_TIMEOUT_SECONDS / 2
        return b"x"


slow_connection = type("Connection", (), {"sock": FakeSocket()})()
original_monotonic = native_host.time.monotonic
native_host.time.monotonic = lambda: clock[0]
try:
    native_host.FaviconCache._read_response(
        SlowResponse(), slow_connection, native_host.FAVICON_TIMEOUT_SECONDS
    )
    raise AssertionError("slow favicon stream exceeded the total deadline")
except TimeoutError:
    pass
finally:
    native_host.time.monotonic = original_monotonic
favicon_url = "https://Example.COM:443/favicon.png#ignored"
canonical_favicon_url = "https://example.com/favicon.png"
cache_root = runtime_dir / "favicon-cache"


def wait_for_cache(cache):
    cache.executor.shutdown(wait=True)


hit_cache = native_host.FaviconCache(
    cache_dir=cache_root / "hit", fetcher=lambda _: ("image/png", png)
)
hit_cache._store(canonical_favicon_url, "image/png", png)
cached_path = hit_cache.get(favicon_url)
assert cached_path is not None
assert cached_path.is_absolute()
assert cached_path.parent == (cache_root / "hit").resolve()
assert cached_path.stat().st_mode & 0o077 == 0
source_tabs = [{
    "id": 90,
    "windowId": 9,
    "index": 0,
    "active": True,
    "favIconUrl": favicon_url,
}]
enriched_tabs = hit_cache.enrich_tabs(source_tabs)
assert "iconPath" not in source_tabs[0]
assert enriched_tabs[0]["iconPath"] == str(cached_path)
assert enriched_tabs[0]["iconPath"] != favicon_url
hit_cache.close()

rejected_calls = []
rejected_cache = native_host.FaviconCache(
    cache_dir=cache_root / "rejected",
    fetcher=lambda url: rejected_calls.append(url) or ("image/png", png),
)
rejected_tabs = rejected_cache.enrich_tabs([
    {"id": 1, "windowId": 1, "index": 0, "active": True, "favIconUrl": "http://example.com/favicon.ico"},
    {"id": 2, "windowId": 1, "index": 1, "active": False, "favIconUrl": "data:image/png;base64,AAAA"},
    {"id": 3, "windowId": 1, "index": 2, "active": False, "favIconUrl": "about:blank"},
    {"id": 4, "windowId": 1, "index": 3, "active": False, "favIconUrl": "https://user@example.com/favicon.ico"},
])
assert all("iconPath" not in tab for tab in rejected_tabs)
assert not rejected_calls
wait_for_cache(rejected_cache)

redirect_cache = native_host.FaviconCache(
    cache_dir=cache_root / "redirect",
    fetcher=lambda url: (_ for _ in ()).throw(
        urllib.error.HTTPError(url, 302, "Found", {}, None)
    ),
)
redirect_cache.schedule(canonical_favicon_url)
wait_for_cache(redirect_cache)
assert redirect_cache.get(canonical_favicon_url) is None
try:
    native_host.RejectRedirects().redirect_request(
        type("Request", (), {"full_url": canonical_favicon_url})(),
        None,
        302,
        "Found",
        {},
        "https://elsewhere.example/favicon.ico",
    )
    raise AssertionError("redirect handler accepted a redirect")
except urllib.error.HTTPError:
    pass

invalid_content_cache = native_host.FaviconCache(
    cache_dir=cache_root / "invalid-content",
    fetcher=lambda _: ("text/html", b"<html>not an image</html>"),
)
invalid_content_cache.schedule(canonical_favicon_url)
wait_for_cache(invalid_content_cache)
assert invalid_content_cache.get(canonical_favicon_url) is None

oversize_cache = native_host.FaviconCache(
    cache_dir=cache_root / "oversize",
    fetcher=lambda _: ("image/png", png + b"x" * native_host.MAX_FAVICON_BYTES),
)
oversize_cache.schedule(canonical_favicon_url)
wait_for_cache(oversize_cache)
assert oversize_cache.get(canonical_favicon_url) is None

eviction_cache = native_host.FaviconCache(
    cache_dir=cache_root / "eviction", fetcher=lambda _: ("image/png", png)
)
previous_entry_limit = native_host.MAX_FAVICON_CACHE_ENTRIES
try:
    native_host.MAX_FAVICON_CACHE_ENTRIES = 1
    older_url = "https://example.com/older.png"
    newer_url = "https://example.com/newer.png"
    eviction_cache._store(older_url, "image/png", png)
    os.utime(
        eviction_cache._cache_path(older_url, "png"),
        (time.time() - 10, time.time() - 10),
    )
    eviction_cache._store(newer_url, "image/png", png)
    assert eviction_cache.get(older_url) is None
    assert eviction_cache.get(newer_url) is not None
finally:
    native_host.MAX_FAVICON_CACHE_ENTRIES = previous_entry_limit
    eviction_cache.close()

failed_cache = native_host.FaviconCache(
    cache_dir=cache_root / "failed",
    fetcher=lambda _: (_ for _ in ()).throw(OSError("network unavailable")),
)
failed_cache.schedule(canonical_favicon_url)
wait_for_cache(failed_cache)
assert failed_cache.get(canonical_favicon_url) is None

fetch_started = threading.Event()
allow_fetch = threading.Event()
replace_started = threading.Event()
allow_replace = threading.Event()
atomic_cache = native_host.FaviconCache(
    cache_dir=cache_root / "atomic",
    fetcher=lambda _: (
        fetch_started.set(),
        allow_fetch.wait(2),
        ("image/png", png),
    )[-1],
)
original_replace = native_host.os.replace


def paused_replace(source, destination):
    replace_started.set()
    assert allow_replace.wait(2), "atomic cache write was not released"
    return original_replace(source, destination)


native_host.os.replace = paused_replace
try:
    atomic_cache.schedule(canonical_favicon_url)
    assert fetch_started.wait(1), "asynchronous favicon fetch did not start"
    allow_fetch.set()
    assert replace_started.wait(1), "atomic cache write did not reach publication"
    assert not atomic_cache._cache_path(canonical_favicon_url, "png").exists()
finally:
    allow_fetch.set()
    allow_replace.set()
    native_host.os.replace = original_replace
wait_for_cache(atomic_cache)
assert atomic_cache.get(canonical_favicon_url) is not None

nonblocking_started = threading.Event()
allow_nonblocking_fetch = threading.Event()
nonblocking_cache = native_host.FaviconCache(
    cache_dir=cache_root / "nonblocking",
    fetcher=lambda _: (
        nonblocking_started.set(),
        allow_nonblocking_fetch.wait(2),
        ("image/png", png),
    )[-1],
)
tab = {
    "id": 91,
    "windowId": 9,
    "index": 1,
    "active": False,
    "favIconUrl": canonical_favicon_url,
}
started_at = time.monotonic()
first_response = nonblocking_cache.enrich_tabs([tab])
assert time.monotonic() - started_at < 0.25
assert "iconPath" not in first_response[0]
assert nonblocking_started.wait(1), "favicon fetch was not scheduled"
allow_nonblocking_fetch.set()
wait_for_cache(nonblocking_cache)
second_response = nonblocking_cache.enrich_tabs([tab])
assert second_response[0]["iconPath"].startswith(str((cache_root / "nonblocking").resolve()))

ttl_cache = native_host.FaviconCache(
    cache_dir=cache_root / "ttl", fetcher=lambda _: ("image/png", png)
)
ttl_cache._store(canonical_favicon_url, "image/png", png)
ttl_path = ttl_cache._cache_path(canonical_favicon_url, "png")
fetched_at = time.time() - 60
os.utime(ttl_path, (fetched_at - 10, fetched_at))
assert ttl_cache.get(canonical_favicon_url) is not None
assert abs(ttl_path.stat().st_mtime - fetched_at) < 0.01, "cache hit rewrote fetch timestamp"
orphan = ttl_cache.cache_dir / f".{ttl_cache._cache_key(canonical_favicon_url)}.abandoned"
orphan.write_bytes(png)
os.utime(orphan, (fetched_at, time.time() - native_host.FAVICON_CACHE_TTL_SECONDS - 1))
ttl_cache._evict()
assert not orphan.exists(), "abandoned cache temporary file survived eviction"
ttl_cache.close()

queued_started = [threading.Event(), threading.Event()]
queued_release = threading.Event()
queued_calls = []
def queued_fetch(url):
    queued_calls.append(url)
    queued_started[len(queued_calls) - 1].set()
    assert queued_release.wait(2), "bounded favicon work was not released"
    return "image/png", png


queue_cache = native_host.FaviconCache(cache_dir=cache_root / "queue", fetcher=queued_fetch)
previous_work_limit = native_host.MAX_FAVICON_WORK_ITEMS
native_host.MAX_FAVICON_WORK_ITEMS = 2
try:
    queue_cache.schedule("https://example.com/one.png")
    queue_cache.schedule("https://example.com/two.png")
    assert queued_started[0].wait(1) and queued_started[1].wait(1)
    queue_cache.schedule("https://example.com/three.png")
    queue_cache.schedule("https://example.com/one.png")
    assert len(queue_cache.in_flight) == 2
    assert "https://example.com/three.png" not in queue_cache.in_flight
    assert len(queued_calls) == 2, "work admission queued excess favicon downloads"
finally:
    native_host.MAX_FAVICON_WORK_ITEMS = previous_work_limit
    queued_release.set()
wait_for_cache(queue_cache)
assert not queue_cache.in_flight, "favicon capacity was not released after completion"

class IconCache:
    def enrich_tabs(self, tabs):
        return [{**tab, "iconPath": "/cache/favicon.png"} for tab in tabs]


response_tab = {"id": 1, "windowId": 1, "index": 0, "active": True, "title": ""}
while len(json.dumps({"id": "response", "ok": True, "tabs": [response_tab]}, separators=(",", ":")).encode()) <= native_host.MAX_MESSAGE_BYTES - 24:
    response_tab["title"] += "x"
bounded = native_host.bounded_list_tabs_response(
    {"id": "response", "ok": True, "tabs": [response_tab]}, IconCache()
)
assert "iconPath" not in bounded["tabs"][0], "oversized optional iconPath was retained"


class FailingIconCache:
    def enrich_tabs(self, tabs):
        raise RuntimeError("favicon cache unavailable")


fallback = native_host.bounded_list_tabs_response(
    {"id": "fallback", "ok": True, "tabs": [{"id": 1, "windowId": 1, "index": 0, "active": True}]},
    FailingIconCache(),
)
assert fallback == {
    "id": "fallback",
    "ok": True,
    "tabs": [{"id": 1, "windowId": 1, "index": 0, "active": True}],
}, "favicon cache failure broke the tab list"
too_large_tab = dict(response_tab, title=response_tab["title"] + "x" * 64)
try:
    native_host.bounded_list_tabs_response(
        {"id": "response", "ok": True, "tabs": [too_large_tab]}, IconCache()
    )
    raise AssertionError("oversized list-tabs response was accepted")
except ValueError as error:
    assert "maximum size" in str(error)
native_cache_home = runtime_dir / "host-cache"
native_cache = native_host.FaviconCache(
    cache_dir=native_cache_home / native_host.FAVICON_CACHE_DIRECTORY,
    fetcher=lambda _: ("image/png", png),
)
native_cache._store(canonical_favicon_url, "image/png", png)
native_cached_path = native_cache.get(canonical_favicon_url)
assert native_cached_path is not None
native_cache.close()
environment = {
    **os.environ,
    "XDG_RUNTIME_DIR": str(runtime_dir),
    "XDG_CACHE_HOME": str(native_cache_home),
}
host = subprocess.Popen(
    [sys.executable, host_path],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    env=environment,
)
try:
    for _ in range(100):
        if socket_path.exists():
            break
        time.sleep(0.01)
    assert socket_path.exists(), "native host did not create its socket"
    client = subprocess.Popen(
        [sys.executable, host_path, "--client", "https://example.com/"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=environment,
    )
    header = host.stdout.read(4)
    assert len(header) == 4, "native host did not emit a framed request"
    (size,) = struct.unpack("<I", header)
    message = json.loads(host.stdout.read(size).decode("utf-8"))
    assert message["type"] == "focus-existing"
    assert message["url"] == "https://example.com/"
    response = json.dumps({
        "id": message["id"],
        "ok": False,
        "error": "No matching HTTP(S) tab found",
    }).encode("utf-8")
    host.stdin.write(struct.pack("<I", len(response)) + response)
    host.stdin.flush()
    assert client.wait(timeout=3) == 1
    assert "No matching HTTP(S) tab found" in client.stderr.read().decode("utf-8")

    client = subprocess.Popen(
        [sys.executable, host_path, "--client", "https://example.com/"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=environment,
    )
    header = host.stdout.read(4)
    assert len(header) == 4, "native host did not emit a second framed request"
    (size,) = struct.unpack("<I", header)
    message = json.loads(host.stdout.read(size).decode("utf-8"))
    assert message["type"] == "focus-existing"
    response = json.dumps({"id": message["id"], "ok": True, "action": "focused"}).encode("utf-8")
    host.stdin.write(struct.pack("<I", len(response)) + response)
    host.stdin.flush()
    assert client.wait(timeout=3) == 0, client.stderr.read().decode("utf-8")

    client = subprocess.Popen(
        [sys.executable, host_path, "--tabs-client", "list"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=environment,
    )
    header = host.stdout.read(4)
    assert len(header) == 4, "native host did not emit a tab-list request"
    (size,) = struct.unpack("<I", header)
    message = json.loads(host.stdout.read(size).decode("utf-8"))
    assert message["type"] == "tab-operation"
    assert message["action"] == "list-tabs"
    response = json.dumps({
        "id": message["id"],
        "ok": True,
        "tabs": [{
            "id": 71,
            "windowId": 8,
            "index": 0,
            "active": True,
            "title": "Example",
            "url": "https://example.com/",
            "favIconUrl": canonical_favicon_url,
        }],
    }).encode("utf-8")
    host.stdin.write(struct.pack("<I", len(response)) + response)
    host.stdin.flush()
    assert client.wait(timeout=3) == 0, client.stderr.read().decode("utf-8")
    assert json.loads(client.stdout.read().decode("utf-8")) == [{
        "id": 71,
        "windowId": 8,
        "index": 0,
        "active": True,
        "title": "Example",
        "url": "https://example.com/",
        "favIconUrl": canonical_favicon_url,
        "iconPath": str(native_cached_path),
    }]

    client = subprocess.Popen(
        [sys.executable, host_path, "--tabs-client", "list"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=environment,
    )
    header = host.stdout.read(4)
    assert len(header) == 4, "native host did not emit a failed tab-list request"
    (size,) = struct.unpack("<I", header)
    message = json.loads(host.stdout.read(size).decode("utf-8"))
    response = json.dumps({
        "id": message["id"],
        "ok": False,
        "error": "tabs access denied",
    }).encode("utf-8")
    host.stdin.write(struct.pack("<I", len(response)) + response)
    host.stdin.flush()
    assert client.wait(timeout=3) == 1
    assert "tabs access denied" in client.stderr.read().decode("utf-8")

    client = subprocess.Popen(
        [sys.executable, host_path, "--tabs-client", "activate", "71"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=environment,
    )
    header = host.stdout.read(4)
    assert len(header) == 4, "native host did not emit a tab-activation request"
    (size,) = struct.unpack("<I", header)
    message = json.loads(host.stdout.read(size).decode("utf-8"))
    assert message["type"] == "tab-operation"
    assert message["action"] == "activate-tab"
    assert message["tabId"] == 71
    response = json.dumps({"id": message["id"], "ok": True, "action": "activated"}).encode("utf-8")
    host.stdin.write(struct.pack("<I", len(response)) + response)
    host.stdin.flush()
    assert client.wait(timeout=3) == 0, client.stderr.read().decode("utf-8")

    invalid_client = subprocess.run(
        [sys.executable, host_path, "--tabs-client", "activate", "invalid"],
        capture_output=True,
        env=environment,
        text=True,
    )
    assert invalid_client.returncode == 1
    assert "windows-manager-linux-orgm-tabs:" in invalid_client.stderr

    assert native_host.valid_browser_response(
        {"id": "test", "ok": True, "tabs": []}, "list-tabs"
    )
    assert not native_host.valid_browser_response(
        {"id": "test", "ok": True, "action": "focused"}, "list-tabs"
    )
finally:
    host.stdin.close()
    host.wait(timeout=3)
PY

printf 'PASS: Firefox webapp tab bridge is packaged and its client protocol works\n'
