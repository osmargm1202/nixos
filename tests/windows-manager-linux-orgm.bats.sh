#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="$ROOT/nixos/packages/windows-manager-linux-orgm/native-host.py"
MANIFEST="$ROOT/nixos/packages/windows-manager-linux-orgm/manifest.json"
PACKAGE="$ROOT/nixos/packages/windows-manager-linux-orgm.nix"
MODULE="$ROOT/nixos/firefox.nix"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

python3 -m json.tool "$MANIFEST" >/dev/null
python3 -m py_compile "$HOST"
grep -Fq '"manifest_version": 2' "$MANIFEST" || fail 'Firefox extension must keep a persistent background page'
grep -Fq '"strict_min_version": "142.0"' "$MANIFEST" || fail 'Firefox extension must require the first Android version supporting data consent'
grep -Fq '"persistent": true' "$MANIFEST" || fail 'Firefox extension must retain the native bridge connection'
grep -Fq '"nativeMessaging"' "$MANIFEST" || fail 'Firefox extension lacks native messaging permission'
grep -Fq '"data_collection_permissions"' "$MANIFEST" || fail 'Firefox extension must declare its data collection policy'
grep -Fq '"required": ["none"]' "$MANIFEST" || fail 'Firefox extension must declare that it collects no data'
grep -Fq 'nativeMessagingHosts.packages = [ windowsManagerLinuxOrgm ];' "$MODULE" || fail 'browser must expose the native host'
grep -Fq 'windows-manager-linux-orgm-signed.xpi' "$MODULE" || fail 'browser must await the signed XPI before activation'
grep -Fq 'lib/mozilla/native-messaging-hosts/windows_manager_linux_orgm.json' "$PACKAGE" || fail 'package must install the native host manifest'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
python3 - "$HOST" "$tmp" <<'PY'
import json
import os
import struct
import subprocess
import sys
import time
from pathlib import Path

host_path = sys.argv[1]
runtime_dir = Path(sys.argv[2])
socket_path = runtime_dir / "windows_manager_linux_orgm.sock"
environment = {**os.environ, "XDG_RUNTIME_DIR": str(runtime_dir)}
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
    assert message["type"] == "focus-or-create"
    assert message["url"] == "https://example.com/"
    response = json.dumps({"id": message["id"], "ok": True, "action": "focused"}).encode("utf-8")
    host.stdin.write(struct.pack("<I", len(response)) + response)
    host.stdin.flush()
    assert client.wait(timeout=3) == 0, client.stderr.read().decode("utf-8")
finally:
    host.stdin.close()
    host.wait(timeout=3)
PY

printf 'PASS: Firefox webapp tab bridge is packaged and its client protocol works\n'
