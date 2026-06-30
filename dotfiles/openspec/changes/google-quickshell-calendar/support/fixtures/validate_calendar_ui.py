#!/usr/bin/env python3
"""Static/fixture checks for Slice 3 Quickshell calendar UI."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
FIXTURE_DIR = Path(__file__).resolve().parent / "calendar-cache"
QML = ROOT / "config/shared/.config/quickshell/calendar/shell.qml"

REQUIRED_QML_MARKERS = [
    "FileView",
    "watchChanges: true",
    "orgm-hypr",
    "calendar",
    "sync",
    "add",
    "open-web",
    "open-event",
    "ui-request.json",
    "requestedAt",
    "Win+Shift+C",
    "Month Grid",
    "Agenda",
    "stale",
    "parse_error",
]


def load_json_fixture(name: str) -> dict:
    path = FIXTURE_DIR / name
    return json.loads(path.read_text(encoding="utf-8"))


def assert_cache_contract(payload: dict, *, expected_state: str) -> None:
    assert payload["schemaVersion"] == 1
    assert payload["source"]["backend"] == "gcalcli"
    assert payload["status"]["state"] == expected_state
    assert isinstance(payload["events"], list)
    for event in payload["events"]:
        for key in ["id", "stableKey", "title", "startDate", "endDate", "allDay"]:
            assert key in event, f"missing event key {key}"


def test_fixtures_cover_ui_states() -> None:
    normal = load_json_fixture("normal-month.json")
    assert_cache_contract(normal, expected_state="ok")
    assert [event["title"] for event in normal["events"]] == ["Project review", "Payday"]
    assert any(event["htmlLink"] for event in normal["events"]), "open-event fixture needs an event link"

    empty = load_json_fixture("empty-day.json")
    assert_cache_contract(empty, expected_state="empty")
    assert empty["events"] == []

    stale = load_json_fixture("stale-error.json")
    assert_cache_contract(stale, expected_state="network_error")
    assert stale["status"]["stale"] is True
    assert stale["events"][0]["title"] == "Cached planning call"

    malformed_text = (FIXTURE_DIR / "malformed.json").read_text(encoding="utf-8")
    try:
        json.loads(malformed_text)
    except json.JSONDecodeError:
        pass
    else:
        raise AssertionError("malformed fixture must be invalid JSON")


def test_qml_static_contract() -> None:
    assert QML.exists(), f"missing {QML}"
    text = QML.read_text(encoding="utf-8")
    for marker in REQUIRED_QML_MARKERS:
        assert marker in text, f"QML missing marker: {marker}"
    assert "gcalcli" not in text.lower(), "QML must not call gcalcli directly"
    assert "orgm-calendar" in text, "QML may keep compatible orgm-calendar cache/state paths"
    assert '["orgm-hypr", "calendar"]' in text, "QML should launch orgm-hypr calendar actions only"
    assert '["orgm-calendar"]' not in text, "QML must not launch standalone orgm-calendar"


if __name__ == "__main__":
    test_fixtures_cover_ui_states()
    test_qml_static_contract()
    print("calendar UI fixture/static checks passed")
