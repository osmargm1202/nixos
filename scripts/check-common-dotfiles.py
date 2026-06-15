#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOTFILES_JSON = Path("/home/osmarg/Hobby/dotfiles/config/dotfiles.json")
NIX_FILE = ROOT / "nixos" / "common-dotfiles.nix"


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def extract_list(source: str, name: str) -> list[str]:
    match = re.search(rf"\n\s*{re.escape(name)}\s*=\s*\[(.*?)\];", source, re.S)
    if not match:
        fail(f"missing list {name} in {NIX_FILE}")
    return re.findall(r'"((?:[^"\\]|\\.)*)"', match.group(1))


def extract_host_lists(source: str) -> dict[str, list[str]]:
    match = re.search(r"\n\s*hostPaths\s*=\s*\{(.*?)\n\s*\};", source, re.S)
    if not match:
        fail(f"missing hostPaths attrset in {NIX_FILE}")
    body = match.group(1)
    hosts: dict[str, list[str]] = {}
    for host_match in re.finditer(r"\n\s*([A-Za-z0-9_-]+)\s*=\s*\[(.*?)\];", body, re.S):
        hosts[host_match.group(1)] = re.findall(r'"((?:[^"\\]|\\.)*)"', host_match.group(2))
    return hosts


def assert_same(label: str, expected: list[str], actual: list[str]) -> None:
    expected_set = set(expected)
    actual_set = set(actual)
    missing = sorted(expected_set - actual_set)
    extra = sorted(actual_set - expected_set)
    if missing or extra:
        details = []
        if missing:
            details.append(f"missing={missing}")
        if extra:
            details.append(f"extra={extra}")
        fail(f"{label} mismatch: {'; '.join(details)}")


def main() -> None:
    if not DOTFILES_JSON.exists():
        fail(f"missing {DOTFILES_JSON}")
    if not NIX_FILE.exists():
        fail(f"missing {NIX_FILE}")

    data = json.loads(DOTFILES_JSON.read_text())
    nix = NIX_FILE.read_text()

    assert_same("sharedPaths", data["shared"]["paths"], extract_list(nix, "sharedPaths"))
    assert_same("localOnlyPaths", data["local_only"]["paths"], extract_list(nix, "localOnlyPaths"))
    assert_same("localOnlyPatterns", data["local_only"]["patterns"], extract_list(nix, "localOnlyPatterns"))
    assert_same("localOnlyTypes", data["local_only"]["types"], extract_list(nix, "localOnlyTypes"))
    assert_same("localDefaultsPaths", data["local_defaults"]["paths"], extract_list(nix, "localDefaultsPaths"))

    actual_hosts = extract_host_lists(nix)
    expected_hosts = data["hosts"]
    if set(actual_hosts) != set(expected_hosts):
        fail(f"host set mismatch: expected={sorted(expected_hosts)} actual={sorted(actual_hosts)}")
    for host, host_data in expected_hosts.items():
        assert_same(f"hostPaths.{host}", host_data["paths"], actual_hosts[host])

    print("OK: common-dotfiles.nix matches dotfiles.json inventory")


if __name__ == "__main__":
    main()
