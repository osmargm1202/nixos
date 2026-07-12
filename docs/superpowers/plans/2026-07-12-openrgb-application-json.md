# OpenRGB Application JSON Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Load G213 focus and notification application colors from JSON and add uniform orange lighting for the Chromium Crunchyroll web application.

**Architecture:** `apps.json` becomes the runtime source of application match patterns and colors. `main.py` validates entries independently, converts strict hexadecimal colors to `RGBColor`, and reuses existing focus, ambient, and notification effects.

**Tech Stack:** Python 3.13, standard-library `json`, `pathlib`, `unittest`, `openrgb-python`, NixOS/Home Manager dotfiles, systemd user services.

## Global Constraints

- Match window classes and notification names using case-insensitive substring matching.
- Each application has one uniform `#RRGGBB` color.
- Crunchyroll uses `#F28C28` and matches `chrome-www.crunchyroll.com__-Default` through pattern `crunchyroll`.
- Missing or malformed configuration yields no rules without terminating the service.
- Invalid entries are skipped independently while valid entries survive.
- Existing OpenRGB connection, retries, blink timing, locking, and `.orp` restoration remain unchanged.
- Dotfiles changes are deployed through the NixOS/Home Manager configuration with `nh os switch`.

---

### Task 1: JSON loader and matching model

**Files:**
- Modify: `tests/openrgb/test_lg213.py`
- Modify: `dotfiles/config/shared/.config/openrgb/lg213/main.py`

**Interfaces:**
- Produces: `ApplicationRule(name: str, window_classes: tuple[str, ...], notification_names: tuple[str, ...], color: RGBColor)`
- Produces: `parse_hex_color(value: str) -> RGBColor`
- Produces: `load_application_rules(path: pathlib.Path | None = None) -> list[ApplicationRule]`
- Produces: `match_rule(rules: list[ApplicationRule], name: str, field: str) -> ApplicationRule | None`

- [ ] **Step 1: Write failing loader and matching tests**

Add imports `json` and `tempfile`, then add tests that write temporary JSON and assert:

```python
class ApplicationConfigurationTests(unittest.TestCase):
    def write_config(self, payload):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "apps.json"
        path.write_text(json.dumps(payload), encoding="utf-8")
        return path

    def test_loads_color_and_matches_chromium_crunchyroll_class(self):
        path = self.write_config({"applications": [{
            "name": "Crunchyroll",
            "windowClasses": ["crunchyroll"],
            "notificationNames": ["Crunchyroll"],
            "color": "#F28C28",
        }]})
        rules = lg213.load_application_rules(path)
        self.assertEqual(rules[0].color, RGBColor(242, 140, 40))
        match = lg213.match_rule(
            rules, "chrome-www.crunchyroll.com__-Default", "window_classes"
        )
        self.assertEqual(match.name, "Crunchyroll")
        self.assertIs(
            lg213.match_rule(rules, "CRUNCHYROLL", "notification_names"), rules[0]
        )

    def test_missing_or_malformed_config_returns_no_rules(self):
        self.assertEqual(lg213.load_application_rules(Path("/missing/apps.json")), [])
        path = self.write_config({"applications": "invalid"})
        self.assertEqual(lg213.load_application_rules(path), [])

    def test_invalid_entry_is_skipped_without_losing_valid_entry(self):
        path = self.write_config({"applications": [
            {"name": "Bad", "windowClasses": ["bad"], "color": "orange"},
            {"name": "Steam", "windowClasses": ["steam"], "color": "#0000FF"},
        ]})
        rules = lg213.load_application_rules(path)
        self.assertEqual([rule.name for rule in rules], ["Steam"])
```

- [ ] **Step 2: Run tests and verify failure**

Run: `python -m unittest tests.openrgb.test_lg213.ApplicationConfigurationTests -v`
Expected: FAIL because configuration functions do not exist.

- [ ] **Step 3: Implement minimal validated model and loader**

In `main.py`, import `json`, `dataclass`, and `Path`; define immutable `ApplicationRule`; strictly parse `#RRGGBB`; load `apps.json` beside the script by default; validate root, names, lists, and at least one non-empty matcher; log and skip invalid entries. Define `match_rule` to inspect the named tuple field in JSON order using lowercase substring matching.

Core signatures and parsing:

```python
@dataclass(frozen=True)
class ApplicationRule:
    name: str
    window_classes: tuple[str, ...]
    notification_names: tuple[str, ...]
    color: RGBColor

CONFIG_PATH = Path(__file__).with_name("apps.json")


def parse_hex_color(value: str) -> RGBColor:
    if not isinstance(value, str) or re.fullmatch(r"#[0-9a-fA-F]{6}", value) is None:
        raise ValueError("color must use #RRGGBB")
    return RGBColor(*(int(value[index:index + 2], 16) for index in (1, 3, 5)))
```

`load_application_rules()` catches file/JSON/root errors and returns `[]`; each entry has its own `try/except (TypeError, ValueError, KeyError)` so later valid entries survive.

- [ ] **Step 4: Run configuration tests**

Run: `python -m unittest tests.openrgb.test_lg213.ApplicationConfigurationTests -v`
Expected: 3 tests PASS.

- [ ] **Step 5: Run existing tests**

Run: `python -m unittest tests.openrgb.test_lg213 -v`
Expected: all tests PASS.

- [ ] **Step 6: Commit loader**

```bash
git add dotfiles/config/shared/.config/openrgb/lg213/main.py tests/openrgb/test_lg213.py
git commit -m "feat(openrgb): load application color rules from JSON"
```

---

### Task 2: Runtime integration and application configuration

**Files:**
- Create: `dotfiles/config/shared/.config/openrgb/lg213/apps.json`
- Modify: `dotfiles/config/shared/.config/openrgb/lg213/main.py`
- Modify: `tests/openrgb/test_lg213.py`

**Interfaces:**
- Consumes: `load_application_rules()`, `match_rule()`, `ApplicationRule.color`
- Changes: `G213Notifier.__init__(rules: list[ApplicationRule] | None = None)` loads default rules when omitted.
- Changes: `on_focus()` and `on_notification()` use configured rules.

- [ ] **Step 1: Write failing runtime tests**

Add tests asserting injected Crunchyroll rules drive focus and notification behavior:

```python
class ConfiguredRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.orange = RGBColor(242, 140, 40)
        self.rule = lg213.ApplicationRule(
            "Crunchyroll", ("crunchyroll",), ("crunchyroll",), self.orange
        )
        self.notifier = lg213.G213Notifier([self.rule])
        self.notifier.apply_ambient = MagicMock()

    def test_crunchyroll_focus_sets_uniform_ambient_color(self):
        self.notifier.on_focus("chrome-www.crunchyroll.com__-Default")
        self.assertEqual(self.notifier.ambient_color, self.orange)
        self.notifier.apply_ambient.assert_called_once_with()

    @patch.object(lg213.threading, "Thread")
    def test_crunchyroll_notification_starts_orange_blink(self, thread):
        self.notifier.on_notification("Crunchyroll")
        thread.assert_called_once_with(
            target=self.notifier.blink, args=(self.orange,), daemon=True
        )
        thread.return_value.start.assert_called_once_with()
```

Also load repository `apps.json` and verify names/colors for Discord, Vesktop, Dota, Steam, and Crunchyroll.

- [ ] **Step 2: Run runtime tests and verify failure**

Run: `python -m unittest tests.openrgb.test_lg213.ConfiguredRuntimeTests -v`
Expected: FAIL because notifier does not accept rules and still uses Python dictionaries.

- [ ] **Step 3: Create application JSON**

Create:

```json
{
  "applications": [
    {"name": "Discord", "windowClasses": ["discord"], "notificationNames": ["discord"], "color": "#FF0000"},
    {"name": "Vesktop", "windowClasses": ["vesktop"], "notificationNames": ["vesktop"], "color": "#FF0000"},
    {"name": "Dota", "windowClasses": ["dota"], "notificationNames": ["dota"], "color": "#FF0000"},
    {"name": "Steam", "windowClasses": ["steam"], "notificationNames": ["steam"], "color": "#0000FF"},
    {"name": "Crunchyroll", "windowClasses": ["crunchyroll"], "notificationNames": ["crunchyroll"], "color": "#F28C28"}
  ]
}
```

- [ ] **Step 4: Integrate rules into notifier**

Remove `NOTIFY_COLORS` and `FOCUS_COLORS`. Accept optional injected rules in `G213Notifier.__init__`; load defaults only when argument is `None`. `on_focus()` matches `window_classes`; `on_notification()` matches `notification_names`. Preserve current log messages and effect calls.

- [ ] **Step 5: Run focused tests**

Run: `python -m unittest tests.openrgb.test_lg213.ConfiguredRuntimeTests -v`
Expected: 2 tests PASS.

- [ ] **Step 6: Run complete OpenRGB suite**

Run: `python -m unittest tests.openrgb.test_lg213 -v`
Expected: all tests PASS.

- [ ] **Step 7: Validate JSON syntax**

Run: `python -m json.tool dotfiles/config/shared/.config/openrgb/lg213/apps.json >/dev/null`
Expected: exit 0.

- [ ] **Step 8: Commit runtime integration**

```bash
git add dotfiles/config/shared/.config/openrgb/lg213/apps.json dotfiles/config/shared/.config/openrgb/lg213/main.py tests/openrgb/test_lg213.py
git commit -m "feat(openrgb): configure Crunchyroll keyboard color"
```

---

### Task 3: Deployment verification

**Files:**
- Verify only; no planned source changes.

**Interfaces:**
- Consumes completed dotfiles and tests.
- Produces synchronized live OpenRGB configuration and restarted service.

- [ ] **Step 1: Run full repository-relevant tests**

Run: `python -m unittest tests.openrgb.test_lg213 -v`
Expected: all tests PASS.

- [ ] **Step 2: Deploy NixOS and Home Manager configuration**

Run: `nh os switch`
Expected: exit 0 and live OpenRGB files updated from the repository.

- [ ] **Step 3: Restart and inspect service**

Run: `systemctl --user restart openrgb-notify.service && systemctl --user --no-pager --full status openrgb-notify.service`
Expected: service active/running with no JSON loading error.

- [ ] **Step 4: Verify final repository state and commit**

Run: `git status --short`
Expected: only pre-existing unrelated changes remain; feature files are clean.
