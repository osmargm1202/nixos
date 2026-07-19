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
base_tools = {"read", "grep", "find", "ls", "bash", "symbol_search", "module_report", "read_symbol", "read_enclosing"}
diagnostic_tools = {"lsp_diagnostics", "lens_diagnostics"}
write_tools = {"write", "edit"}
context7_tools = {"context7_resolve-library-id", "context7_query-docs"}
tool_contracts = {
    "planner": base_tools,
    "builder": base_tools | write_tools | diagnostic_tools,
    "sdd-explorer": base_tools | context7_tools,
    "sdd-spec": base_tools | write_tools,
    "sdd-design": base_tools | write_tools,
    "sdd-plan": base_tools | write_tools,
    "sdd-tasks": base_tools | write_tools,
    "sdd-builder": base_tools | write_tools | diagnostic_tools,
    "sdd-reviewer": base_tools | diagnostic_tools,
    "sdd-verifier": base_tools | diagnostic_tools,
    "tdd-planner": base_tools | write_tools,
    "tdd-builder": base_tools | write_tools | diagnostic_tools,
    "tdd-reviewer": base_tools | diagnostic_tools,
    "tdd-verifier": base_tools | diagnostic_tools,
}


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
    if not re.fullmatch(r"[a-z][a-z0-9]*(?:-[a-z0-9]+)*", name):
        fail(f"{name}: name must be lowercase kebab-case")
    if set(metadata) != {"name", "description"}:
        fail(f"{name}: frontmatter keys must be name, description, and tools only")
    if metadata.get("name") != name:
        fail(f"{name}: frontmatter name mismatch")
    if not metadata.get("description"):
        fail(f"{name}: missing trigger-focused description")
    if len(tools) != len(set(tools)):
        fail(f"{name}: duplicate tool entries")
    actual_tools = set(tools)
    wanted_tools = tool_contracts[name]
    if actual_tools != wanted_tools:
        fail(f"{name}: tool contract mismatch; missing={sorted(wanted_tools - actual_tools)}, extra={sorted(actual_tools - wanted_tools)}")
    markers = (
        "## Boundaries",
        "## Output contract",
        "next_recommended",
        "DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED",
        "Advance to `next_recommended` only when status is `DONE`",
    )
    for marker in markers:
        if marker not in body:
            fail(f"{name}: missing body contract marker {marker}")
    if "subagent_*" not in body:
        fail(f"{name}: missing explicit no-delegation rule")


def check_config() -> None:
    if not config_path.is_file():
        fail(f"missing config: {config_path}")
    config = json.loads(config_path.read_text())
    expected_values = {
        "mode": "opencode",
        "timeout_ms": 1200000,
        "stall_timeout_ms": 240000,
        "max_concurrency": 5,
        "debug": False,
        "session_resources": "lean",
        "history_panel_shortcut": "ctrl+,",
        "detail_cancel_shortcut": "x",
        "background_handoff_shortcut": "ctrl+h",
        "default_tools": ["read"],
    }
    if set(config) != {*expected_values, "model_profiles"}:
        fail("subagents.json: unexpected or missing top-level fields")
    for key, wanted in expected_values.items():
        if config.get(key) != wanted:
            fail(f"subagents.json: {key} must equal {wanted!r}")
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
    match = re.search(r"(?ms)^\s*sharedPaths\s*=\s*\[(.*?)^\s*\];", text)
    if not match:
        fail("common-dotfiles.nix: sharedPaths list not found")
    shared_paths = re.findall(r'^\s*"([^"]+)"', match.group(1), re.MULTILINE)
    for path in (".pi/agent/subagents", ".pi/agent/subagents.json"):
        if shared_paths.count(path) != 1:
            fail(f"common-dotfiles.nix: expected exactly one {path!r} in sharedPaths")


if group not in {*groups, "deployment", "all"}:
    fail(f"unknown group: {group}")

if group == "all":
    actual_files = {path.stem for path in subagents.glob("*.md")}
    if actual_files != set(expected):
        fail(f"catalog files mismatch; missing={sorted(set(expected) - actual_files)}, extra={sorted(actual_files - set(expected))}")
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
