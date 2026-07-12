# OpenRGB G213 Reliable Ambient Color Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make mapped application focus colors cover all five Logitech G213 lighting areas reliably while preserving profile restoration and notification behavior.

**Architecture:** Keep the existing event listeners and layering model. Add one narrow ambient-write helper that forces Direct mode and retries the same full-device frame four times with 120 ms gaps; route only steady focus colors through it.

**Tech Stack:** Python 3.13, `openrgb-python`, standard-library `unittest`/`unittest.mock`, NixOS/Home Manager dotfiles, systemd user services.

## Global Constraints

- Ambient writes use exactly 4 attempts.
- Wait exactly 0.12 seconds between attempts and never after the final attempt.
- Only focused mapped-app ambient colors use retries.
- Notification palette, frame count, cadence, and locking remain unchanged.
- Base restoration continues loading the selected `.orp` profile through the OpenRGB CLI.
- Do not modify or stage unrelated dirty working-tree files.
- Dotfile rollout uses the NixOS/Home Manager configuration through `nh os switch`.

---

## File Structure

- Create `tests/openrgb/test_lg213.py`: isolated unit tests that stub `openrgb-python`, load the dotfile script by path, and verify ambient retries, restoration, and unchanged notification frames.
- Modify `dotfiles/config/shared/.config/openrgb/lg213/main.py`: add retry constants and the reliable uniform ambient-write helper; keep listeners and notification logic in place.

---

### Task 1: Reliable Uniform Ambient Writes

**Files:**
- Create: `tests/openrgb/test_lg213.py`
- Modify: `dotfiles/config/shared/.config/openrgb/lg213/main.py:55-58,123-130`

**Interfaces:**
- Consumes: `G213Notifier.ensure_direct()`, `G213Notifier._set(colors)`, `G213Notifier.restore_base()`, `self.device.leds`, and `RGBColor`.
- Produces: `G213Notifier._set_uniform_ambient(color: RGBColor) -> None`, `AMBIENT_WRITE_ATTEMPTS`, and `AMBIENT_WRITE_RETRY_SECONDS`.

- [ ] **Step 1: Create the failing unit tests**

Create `tests/openrgb/test_lg213.py` with this complete content:

```python
import importlib.util
import sys
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
```

- [ ] **Step 2: Run tests and verify the ambient retry test fails**

Run:

```bash
python3 -m unittest discover -s tests/openrgb -p 'test_*.py' -v
```

Expected: 3 tests run; `test_mapped_ambient_color_retries_uniform_full_device_frame` fails because current `apply_ambient()` calls `_set()` once, while restoration and notification regression tests pass.

- [ ] **Step 3: Add named retry constants**

In `dotfiles/config/shared/.config/openrgb/lg213/main.py`, replace:

```python
EFFECT_SECONDS = 3.0
FRAME_SECONDS = 0.5  # on/off cadence; G213 writes are slow, keep this coarse
SERVER_RETRY_SECONDS = 5
DEVICE_NAME = "G213"
```

with:

```python
EFFECT_SECONDS = 3.0
FRAME_SECONDS = 0.5  # on/off cadence; G213 writes are slow, keep this coarse
AMBIENT_WRITE_ATTEMPTS = 4
AMBIENT_WRITE_RETRY_SECONDS = 0.12
SERVER_RETRY_SECONDS = 5
DEVICE_NAME = "G213"
```

- [ ] **Step 4: Implement the reliable ambient helper and route focus colors through it**

In `G213Notifier`, replace the current `apply_ambient()` method:

```python
    def apply_ambient(self):
        with self.lock:
            if self.ambient_color is not None:
                self.ensure_direct()
                self._set([self.ambient_color] * len(self.device.leds))
            else:
                self.restore_base()
```

with:

```python
    def _set_uniform_ambient(self, color: RGBColor) -> None:
        """Retry a uniform frame because G213 applies five HID writes separately."""
        self.ensure_direct()
        frame = [color] * len(self.device.leds)
        for attempt in range(AMBIENT_WRITE_ATTEMPTS):
            self._set(frame)
            if attempt + 1 < AMBIENT_WRITE_ATTEMPTS:
                time.sleep(AMBIENT_WRITE_RETRY_SECONDS)

    def apply_ambient(self):
        with self.lock:
            if self.ambient_color is not None:
                self._set_uniform_ambient(self.ambient_color)
            else:
                self.restore_base()
```

Do not change `blink()`; it must continue calling `_set()` directly.

- [ ] **Step 5: Run focused tests and verify all pass**

Run:

```bash
python3 -m unittest discover -s tests/openrgb -p 'test_*.py' -v
```

Expected:

```text
Ran 3 tests
OK
```

- [ ] **Step 6: Run syntax and whitespace checks**

Run:

```bash
python3 -m py_compile dotfiles/config/shared/.config/openrgb/lg213/main.py tests/openrgb/test_lg213.py
git diff --check -- dotfiles/config/shared/.config/openrgb/lg213/main.py tests/openrgb/test_lg213.py
```

Expected: both commands exit 0 with no output.

- [ ] **Step 7: Review only intended source and test changes**

Run:

```bash
git diff -- dotfiles/config/shared/.config/openrgb/lg213/main.py tests/openrgb/test_lg213.py
```

Expected: only two constants, one helper, the `apply_ambient()` routing change, and the new three-test file. No notification implementation changes.

- [ ] **Step 8: Commit the tested implementation without staging unrelated files**

Run:

```bash
git add -- dotfiles/config/shared/.config/openrgb/lg213/main.py tests/openrgb/test_lg213.py
git commit -m "fix(openrgb): retry G213 ambient color writes"
```

Expected: one commit containing only those two paths.

---

### Task 2: Dotfile Rollout and Hardware Verification

**Files:**
- Verify deployed target: `~/.config/openrgb/lg213/main.py`
- No repository files created or modified.

**Interfaces:**
- Consumes: committed retry implementation, `nh os switch`, `openrgb-notify.service`, and `/home/osmarg/.config/OpenRGB/orgm.orp`.
- Produces: live service running the committed script and physical confirmation across all five G213 areas.

- [ ] **Step 1: Apply the NixOS and Home Manager configuration**

Run:

```bash
nh os switch
```

Expected: switch completes successfully and updates `~/.config/openrgb/lg213/main.py` from the repository.

- [ ] **Step 2: Restart the user service and verify startup**

Run:

```bash
systemctl --user restart openrgb-notify.service
systemctl --user is-active openrgb-notify.service
journalctl --user -u openrgb-notify.service -n 20 --no-pager
```

Expected: `is-active` prints `active`; journal contains `connected: Logitech G213 (5 leds)` and no traceback or Direct-mode error.

- [ ] **Step 5: Verify uniform mapped-app focus colors with the user**

Ask the user to perform these observations:

1. Focus Steam: all five areas—Left, Middle, Right, Arrow/Home, and Numpad—are bright blue.
2. Focus Vesktop/Discord or Dota: all five areas are bright red.
3. Switch to an unmapped application: `/home/osmarg/.config/OpenRGB/orgm.orp` lighting returns.

Expected: all three observations pass. If an ambient color is still partial, collect the service journal and stop before increasing retries.

- [ ] **Step 6: Verify notification regression behavior with the user**

Trigger one mapped notification from Vesktop/Discord or Steam.

Expected: existing six-frame, 0.5-second on/off blink remains visually unchanged and the current ambient or base state returns afterward.

- [ ] **Step 7: Record final repository state without modifying unrelated work**

Run:

```bash
git status --short
git show --stat --oneline HEAD
```

Expected: implementation commit lists only `main.py` and `tests/openrgb/test_lg213.py`; pre-existing unrelated dirty paths remain untouched.
