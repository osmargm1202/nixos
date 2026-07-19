#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SUBAGENTS="$ROOT/config/shared/.pi/agent/subagents"
CONFIG="$ROOT/config/shared/.pi/agent/subagents.json"
NIX_MODULE="$ROOT/../nixos/common-dotfiles.nix"
GROUP=${1:-all}

python3 - "$GROUP" "$SUBAGENTS" "$CONFIG" "$NIX_MODULE" <<'PY'
import json
import re
import sys
from pathlib import Path

group, subagents_arg, config_arg, nix_arg = sys.argv[1:]
subagents = Path(subagents_arg)
config_path = Path(config_arg)
nix_module = Path(nix_arg)

groups = {
    "generic": ["planner", "builder"],
    "sdd-planning": ["sdd-explorer", "sdd-spec", "sdd-design", "sdd-plan", "sdd-tasks"],
    "sdd-execution": ["sdd-builder", "sdd-reviewer", "sdd-verifier"],
    "tdd": ["tdd-planner", "tdd-builder", "tdd-reviewer", "tdd-verifier"],
}
expected = [name for names in groups.values() for name in names]
readonly = {
    "planner", "sdd-explorer", "sdd-reviewer", "sdd-verifier",
    "tdd-reviewer", "tdd-verifier",
}
artifact_writers = {"sdd-spec", "sdd-design", "sdd-plan", "sdd-tasks", "tdd-planner"}
builders = {"builder", "sdd-builder", "tdd-builder"}
required_navigation = {"read", "grep", "find", "ls", "bash", "symbol_search", "module_report", "read_symbol", "read_enclosing"}
required_diagnostics = {"lsp_diagnostics", "lens_diagnostics"}


def fail(message: str) -> None:
    raise AssertionError(message)


def parse_agent(name: str) -> tuple[dict[str, str], list[str], str]:
    path = subagents / f"{name}.md"
    if not path.is_file():
        fail(f"missing agent definition: {path}")
    text = path.read_text()
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        fail(f"missing opening frontmatter delimiter: {path}")
    try:
        end = lines.index("---", 1)
    except ValueError:
        fail(f"missing closing frontmatter delimiter: {path}")
    metadata: dict[str, str] = {}
    tools: list[str] = []
    in_tools = False
    for line in lines[1:end]:
        if line == "tools:":
            in_tools = True
            continue
        if in_tools and line.startswith("  - "):
            tools.append(line[4:])
            continue
        in_tools = False
        match = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*):\s*(.*)", line)
        if match:
            metadata[match.group(1)] = match.group(2)
    body = "\n".join(lines[end + 1:]).strip()
    return metadata, tools, body


def check_agent(name: str) -> None:
    metadata, tools, body = parse_agent(name)
    if metadata.get("name") != name:
        fail(f"{name}: frontmatter name mismatch")
    if not metadata.get("description"):
        fail(f"{name}: missing trigger-focused description")
    if not tools:
        fail(f"{name}: empty tool allowlist")
    if any(tool.startswith("subagent_") for tool in tools):
        fail(f"{name}: subagent delegation tool is forbidden")
    missing_navigation = required_navigation - set(tools)
    if missing_navigation:
        fail(f"{name}: missing navigation tools {sorted(missing_navigation)}")
    if name in readonly and ({"write", "edit"} & set(tools)):
        fail(f"{name}: read-only role contains write/edit")
    if name in artifact_writers and not {"write", "edit"}.issubset(tools):
        fail(f"{name}: artifact writer requires write and edit")
    if name in builders:
        required = {"write", "edit"} | required_diagnostics
        if not required.issubset(tools):
            fail(f"{name}: builder missing {sorted(required - set(tools))}")
    if name in {"sdd-reviewer", "sdd-verifier", "tdd-reviewer", "tdd-verifier"}:
        if not required_diagnostics.issubset(tools):
            fail(f"{name}: reviewer/verifier missing diagnostics")
    context7 = {"context7_resolve-library-id", "context7_query-docs"}
    if name == "sdd-explorer" and not context7.issubset(tools):
        fail("sdd-explorer: missing Context7 tools")
    if name != "sdd-explorer" and context7 & set(tools):
        fail(f"{name}: Context7 must be limited to sdd-explorer")
    for marker in ("## Boundaries", "## Output contract", "next_recommended"):
        if marker not in body:
            fail(f"{name}: missing body contract marker {marker}")
    if "subagent_*" not in body:
        fail(f"{name}: missing explicit no-delegation rule")


def check_config() -> None:
    if not config_path.is_file():
        fail(f"missing config: {config_path}")
    config = json.loads(config_path.read_text())
    if config.get("session_resources") != "lean":
        fail("subagents.json: session_resources must be lean")
    if config.get("debug") is not False:
        fail("subagents.json: debug must be false")
    if config.get("default_tools") != ["read"]:
        fail("subagents.json: default_tools must be ['read']")
    profiles = config.get("model_profiles")
    if not isinstance(profiles, dict) or set(profiles) != set(expected):
        fail("subagents.json: model_profiles must match all 14 agents exactly")
    medium = {"sdd-explorer", "sdd-tasks", "sdd-verifier", "tdd-verifier"}
    for name, profile in profiles.items():
        wanted = "medium" if name in medium else "high"
        if profile != {"effort": wanted}:
            fail(f"subagents.json: {name} profile must be effort={wanted} only")


def check_deployment() -> None:
    if not nix_module.is_file():
        fail(f"missing Nix module: {nix_module}")
    text = nix_module.read_text()
    for path in (".pi/agent/subagents", ".pi/agent/subagents.json"):
        marker = f'"{path}"'
        if text.count(marker) != 1:
            fail(f"common-dotfiles.nix: expected exactly one {marker}")


if group not in {*groups, "deployment", "all"}:
    fail(f"unknown group: {group}")

if group == "all":
    check_config()
    for name in expected:
        check_agent(name)
    check_deployment()
elif group == "deployment":
    check_deployment()
else:
    if group == "generic":
        check_config()
    for name in groups[group]:
        check_agent(name)

print(f"pi subagents contract passed: {group}")
PY
