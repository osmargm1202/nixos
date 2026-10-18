#!/usr/bin/env python3
"""Verify the real Hub distinguishes missing hardware from a missing daemon."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
expr = '''let f=builtins.getFlake ("path:"+builtins.getEnv "RYOKU_TEST_REPO");
  c=f.nixosConfigurations.lenovo.config;
  p=(import (builtins.getEnv "RYOKU_TEST_REPO"+"/nixos/profiles/ryoku/provider-compat.nix")
    {inputs=f.inputs;pkgs=f.nixosConfigurations.lenovo.pkgs;lib=f.inputs.nixpkgs.lib;}).packages;
  qs=f.inputs.nixpkgs.lib.findFirst (p: f.inputs.nixpkgs.lib.getName p == "ryoku-qs")
    (throw "Ryoku Quickshell launcher missing") c.systemd.user.services.ryoku-shell.path;
  in [p.ryoku-desktop-data qs]'''
packages = subprocess.check_output(
    ["nix", "build", "--impure", "--no-link", "--print-out-paths", "--expr", expr],
    env=dict(os.environ, RYOKU_TEST_REPO=str(ROOT)), text=True).splitlines()
data = next(Path(p) for p in packages if (Path(p)/"share/ryoku/config").is_dir())
launcher = next(Path(p)/"bin/ryoku-qs" for p in packages if (Path(p)/"bin/ryoku-qs").exists())
with tempfile.TemporaryDirectory() as tmp:
    home = Path(tmp)
    (home/"run").mkdir(mode=0o700)
    (home/"bin").mkdir()
    fake = home/"bin/fprintd-list"
    fake.write_text("#!/bin/sh\nprintf 'No devices available\\n' >&2\n")
    fake.chmod(0o755)
    qml = home/"test.qml"
    qml.write_text('''import QtQuick
import Quickshell
import "file:''' + str(data/"share/ryoku/config/quickshell/hub/pages") + '''" as Pages
ShellRoot {
    property int attempts: 0
    Pages.LockscreenPage { id: page }
    function check(ok, message) {
        if (!ok) { console.log("FAIL " + message); Qt.quit(); }
        return ok;
    }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            attempts++;
            if (attempts > 100) { console.log("FAIL timeout"); Qt.quit(); return; }
            if (attempts < 5 || page.floading) return;
            // This first state comes from the real Process collecting stderr.
            if (!check(page.fdaemon && !page.fready, "no devices is a daemon reply")) return;
            if (!check(page.fStatusLine.indexOf("service is not running") < 0, "wrong status")) return;
            page.fnames = { "right-index-finger": "Personal name" };
            page.fparseList("found 0 devices");
            if (!check(page.fdaemon && !page.fready, "zero device count")) return;
            if (!check(page.fnames["right-index-finger"] === "Personal name", "names lost without hardware")) return;
            page.fparseList("Using device /net/reactivated/Fprint/Device/0\\nFingerprints for test on Sensor (press):\\n - #0: right-index-finger");
            if (!check(page.fdaemon && page.fready && page.ffingers.length === 1, "ready reader")) return;
            page.fparseList("");
            if (!check(!page.fdaemon && !page.fready, "missing daemon")) return;
            console.log("PASS fingerprint daemon, unsupported reader and enrolled reader states");
            Qt.quit();
        }
    }
}
''')
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home/"config"),
        XDG_CACHE_HOME=str(home/"cache"), XDG_RUNTIME_DIR=str(home/"run"),
        DBUS_SESSION_BUS_ADDRESS="unix:path="+str(home/"no-bus"),
        QT_QPA_PLATFORM="offscreen", QSG_RHI_BACKEND="software",
        PATH=str(home/"bin")+":"+os.environ["PATH"])
    for key in ("HYPRLAND_INSTANCE_SIGNATURE", "WAYLAND_DISPLAY", "DISPLAY"):
        env.pop(key, None)
    result = subprocess.run([str(launcher), "-p", str(qml)], env=env,
        capture_output=True, text=True, timeout=15)
    logs = result.stdout+result.stderr
    assert result.returncode == 0 and "PASS fingerprint daemon" in logs and "FAIL " not in logs, logs
    print("PASS: real fingerprint page handles daemon replies without claiming missing software")
