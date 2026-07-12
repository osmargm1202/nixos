import importlib.util
import json
import sys
import tempfile
import types
import unittest
from dataclasses import dataclass
from pathlib import Path
from unittest.mock import MagicMock, call, patch


@dataclass(frozen=True)
class RGBColor:
    red: int
    green: int
    blue: int


fake_openrgb = types.ModuleType("openrgb")
fake_openrgb.OpenRGBClient = MagicMock
fake_utils = types.ModuleType("openrgb.utils")
fake_utils.RGBColor = RGBColor
sys.modules["openrgb"] = fake_openrgb
sys.modules["openrgb.utils"] = fake_utils

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = (
    ROOT / "dotfiles/config/shared/.config/openrgb/lg213/main.py"
)
SPEC = importlib.util.spec_from_file_location("lg213_main", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
lg213 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(lg213)


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

    def test_repository_configuration_has_expected_names_and_colors(self):
        rules = lg213.load_application_rules(
            ROOT / "dotfiles/config/shared/.config/openrgb/lg213/apps.json"
        )
        self.assertEqual(
            {rule.name: rule.color for rule in rules},
            {
                "Discord": RGBColor(255, 0, 0),
                "Vesktop": RGBColor(255, 0, 0),
                "Dota": RGBColor(255, 0, 0),
                "Steam": RGBColor(0, 0, 255),
                "Crunchyroll": self.orange,
            },
        )


class FakeDevice:
    def __init__(self, led_count=5):
        self.leds = [object() for _ in range(led_count)]


class G213NotifierTests(unittest.TestCase):
    def setUp(self):
        self.notifier = lg213.G213Notifier()
        self.notifier.device = FakeDevice()
        self.notifier.ensure_direct = MagicMock()
        self.notifier._set = MagicMock()
        self.notifier.restore_base = MagicMock()

    @patch.object(lg213.time, "sleep")
    def test_mapped_ambient_color_retries_uniform_full_device_frame(self, sleep):
        color = RGBColor(0, 0, 255)
        self.notifier.ambient_color = color

        self.notifier.apply_ambient()

        frame = [color] * 5
        self.notifier.ensure_direct.assert_called_once_with()
        self.assertEqual(
            self.notifier._set.call_args_list,
            [call(frame), call(frame), call(frame), call(frame)],
        )
        self.assertEqual(
            sleep.call_args_list,
            [call(0.12), call(0.12), call(0.12)],
        )
        self.notifier.restore_base.assert_not_called()

    @patch.object(lg213.time, "sleep")
    def test_unmapped_focus_restores_profile_without_retries(self, sleep):
        self.notifier.ambient_color = None

        self.notifier.apply_ambient()

        self.notifier.restore_base.assert_called_once_with()
        self.notifier.ensure_direct.assert_not_called()
        self.notifier._set.assert_not_called()
        sleep.assert_not_called()

    @patch.object(lg213.time, "sleep")
    def test_notification_blink_frames_and_cadence_remain_unchanged(self, sleep):
        self.notifier.apply_ambient = MagicMock()
        base = RGBColor(255, 0, 0)
        white = RGBColor(255, 255, 255)
        dim = RGBColor(63, 0, 0)
        off = RGBColor(0, 0, 0)
        on = [base, white, dim, base, white]

        self.notifier.blink(base)

        self.notifier.ensure_direct.assert_called_once_with()
        self.assertEqual(
            self.notifier._set.call_args_list,
            [call(on), call([off] * 5)] * 3,
        )
        self.assertEqual(sleep.call_args_list, [call(0.5)] * 6)
        self.notifier.apply_ambient.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
